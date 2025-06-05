from setuptools import setup, Extension
from pybind11.setup_helpers import Pybind11Extension, build_ext

ext_modules = [
    Pybind11Extension(
        "mc_copula",
        ["pybind_wrapper.cpp"],
        include_dirs=["/usr/local/cuda/include"],
        library_dirs=["/usr/local/cuda/lib64"],
        libraries=["cudart"],
        extra_compile_args=["-O3", "-std=c++17"],
        language="c++"
    ),
]

setup(
    name="mc_copula",
    version="0.1.0",
    ext_modules=ext_modules,
    cmdclass={"build_ext": build_ext},
)
