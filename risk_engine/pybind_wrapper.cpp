#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <vector>

extern void run_mc(int n_paths, int steps, double mu, double sigma, double s0, double *h_out);

namespace py = pybind11;

py::array_t<double> simulate_mc(int n_paths, int steps, double mu, double sigma, double s0) {
    std::vector<double> results(n_paths);
    run_mc(n_paths, steps, mu, sigma, s0, results.data());
    auto buf = py::array_t<double>(results.size());
    auto buf_mut = buf.mutable_unchecked<1>();
    for (size_t i = 0; i < results.size(); ++i) {
        buf_mut(i) = results[i];
    }
    return buf;
}

PYBIND11_MODULE(mc_copula, m) {
    m.doc() = "Monte Carlo Copula library (C++/CUDA)";
    m.def("simulate", &simulate_mc, "Run MC simulation",
          py::arg("n_paths"), py::arg("steps"), py::arg("mu"), py::arg("sigma"), py::arg("s0"));
}
