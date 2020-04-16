import aiohttp
from aiohttp import web
import sys

from prometheus_client import exposition, Gauge, Counter, CollectorRegistry, Metric
from sunspec.core import client

class SCounter(Counter):
    def set(self, v):
        self._value.set(float(v))


# class SolarAPIException(Exception):
    # pass


def is_counter(mdl, name, outer_name=None):
    if mdl == 'inverter':
        if name == 'WH':
            return True
    elif mdl == 'mppt' and outer_name == 'module':
        if name == 'DCWH':
            return True
    return False


def make_metric_name_labels(mdl, name, outer_name=None, outer_idx=None):
    labels = {}
    if mdl == 'inverter':
        # phase quirks
        phase = None
        if name.startswith('Aph'):
            phase = name[3:]
            name = 'Aph'
        elif name.startswith('PhVph'):
            phase = name[5:]
            name = 'PhV'
        elif name.startswith('PPVph'):
            assert len(name[5:]) == 2
            phase = name[5]
            phase2 = name[6]
            assert phase2 in {'A', 'B', 'C'}
            labels['phase2'] = phase2
            name = 'PPV'
        if phase is not None:
            assert phase in {'A', 'B', 'C'}
            labels['phase'] = phase

    if outer_name is None:
        return ("sunspec_{}_{}".format(mdl, name), labels)
    else:
        assert outer_idx is not None
        labels[outer_name] = outer_idx
        return ("sunspec_{}_{}_{}".format(mdl, outer_name, name), labels)


class ModbusClient:
    def __init__(self, host, device_id, models, registry):
        self.host = host
        self.device_id = device_id
        self.models = set(models)
        self.registry = registry
        self.modelmap = {}
        self.base_labels = {'device_id': device_id}
        self.metrics = {}

    def connect(self):
        self.client = client.SunSpecClientDevice(client.TCP, self.device_id, ipaddr=self.host) #, trace=print)
        c_models = self.client.models
        if not self.models.issubset(c_models):
            raise Exception("requested models not present {}".format(c_models))
        assert 'common' in c_models
        self.client.common.read()
        print("Connected inverter:")
        print(self.client.common)   # TODO
        self._update_models()
        for i in self.models:
            self._register_model(i, getattr(self.client, i))

    def _update_models(self):
        for i in self.models:
            getattr(self.client, i).read()

    def refresh(self):
        self._update_models()
        for mdlname in self.modelmap:
            model = getattr(self.client, mdlname)
            for p, point in self.modelmap[mdlname].items():
                if isinstance(point, dict):     # actually a repeating, not a point
                    for inner_p, inner_point in point.items():
                        inner_model = getattr(model, p)
                        for idx, inner_obj in enumerate(inner_model):
                            if inner_obj is None:
                                assert idx == 0
                                continue
                            self._update_metric(inner_obj, mdlname, inner_p, inner_point, p, idx)
                    continue
                self._update_metric(model, mdlname, p, point)

    def _update_metric(self, obj, mdlname, point_name, point_metric, outer_name=None, outer_idx=None):
        metric, labels = make_metric_name_labels(mdlname, point_name, outer_name, outer_idx)
        assert metric == point_metric, "{} {}".format(metric, point_metric)
        labels.update(self.base_labels)
        v = getattr(obj, point_name)
        if v is None:
            v = 0 # hax TODO
        self.metrics[point_metric].labels(**labels).set(v)

    def _register_model(self, mdlname, mdl):
        assert mdlname not in self.modelmap
        def make_points(obj, pts, d=None, outer=None, outeridx=None):
            md = {} if d is None else d
            for p in pts:
                if type(getattr(obj, p)) in {str, type(None)}:
                    continue
                assert type(getattr(obj, p)) in {int, float}, "{} {}".format(p, getattr(obj, p))
                metric, labels = make_metric_name_labels(mdlname, p, outer, outeridx)
                label_keys = set(labels.keys()).union(set(self.base_labels.keys()))
                md[p] = metric
                if metric in self.metrics:
                    assert set(self.metrics[metric]._labelnames) == label_keys
                    continue
                if is_counter(mdlname, p, outer):
                    m = SCounter(metric, '', list(label_keys), registry=self.registry)
                else:
                    m = Gauge(metric, '', list(label_keys), registry=self.registry)
                self.metrics[metric] = m
            return md
        mdl_dict = make_points(mdl, mdl.points)
        mrd = {}
        for idx,r in enumerate(mdl.repeating):
            if r is None:
                assert idx == 0
                continue
            make_points(r, r.points, mrd, r.name, idx)

        if mrd:
            mdl_dict[mdl.repeating_name] = mrd
        self.modelmap[mdlname] = mdl_dict



def make_handler(mc):
    async def handle_metric(request):
        mc.refresh()
        return web.Response(body=exposition.generate_latest(mc.registry))
    return handle_metric

# async def main(argv):
def main():
    argv = sys.argv
    h = argv[1]
    registry = CollectorRegistry()
    mc = ModbusClient(h, 1, {'inverter', 'mppt'}, registry)
    mc.connect()
    app = web.Application()
    app.add_routes([web.get('/metrics', make_handler(mc))])
    web.run_app(app, port=9111)

if __name__ == '__main__':
    main()
