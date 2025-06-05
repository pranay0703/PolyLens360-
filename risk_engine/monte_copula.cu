#include <vector>
#include <random>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <curand_kernel.h>

__global__ void simulate_kernel(double *d_results, int n_paths, int steps, double mu, double sigma, double s0) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n_paths) return;
    curandState state;
    curand_init(42, idx, 0, &state);
    double dt = 1.0 / steps;
    double S = s0;
    for (int i = 0; i < steps; ++i) {
        double eps = curand_normal_double(&state) * sigma * sqrt(dt) + mu * dt;
        S *= exp(eps);
    }
    d_results[idx] = S;
}

extern "C" void run_mc(int n_paths, int steps, double mu, double sigma, double s0, double *h_out) {
    thrust::device_vector<double> d_results(n_paths);
    double *d_ptr = thrust::raw_pointer_cast(d_results.data());
    int block = 256;
    int grid  = (n_paths + block - 1) / block;
    simulate_kernel<<<grid, block>>>(d_ptr, n_paths, steps, mu, sigma, s0);
    thrust::host_vector<double> h_results = d_results;
    for (int i = 0; i < n_paths; ++i) {
        h_out[i] = h_results[i];
    }
}
