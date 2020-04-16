import setuptools

setuptools.setup(
    name="sunspec_exporter",
    version="0.0.1",
    author="Bartosz Stebel",
    author_email="bartoszstebel@gmail.com",
    description="TODO",
    #long_description=None,
    #long_description_content_type="text/markdown",
    #url="https://github.com/pypa/sampleproject",
    py_modules=["sunspec_exporter"],
    install_requires = ["pysunspec", "aiohttp", "prometheus_client"], # TODO aio
    entry_points={
        'console_scripts': [
            'sunspec_exporter=sunspec_exporter:main',
            ],
        },
    classifiers=[
        "Programming Language :: Python :: 3",
    #    "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        ],
    python_requires='>=3.6',
)
