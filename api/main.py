from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import json, os
import mc_copula

app = FastAPI()
PARAM_FILE = "../rstats/garch_vine_params.json"

class StressRequest(BaseModel):
    scenario: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/stress")
def stress(req: StressRequest):
    if not os.path.exists(PARAM_FILE):
        raise HTTPException(status_code=500, detail="Params not found")
    with open(PARAM_FILE) as f:
        params = json.load(f)

    n_paths = 20000
    steps   = 252
    # Example: use mu of first asset
    first_asset = next(k for k in params.keys() if k != "vine_structure")
    mu = params[first_asset]["mu"]
    sigma   = 0.2
    s0      = 100.0

    sim_results = mc_copula.simulate(n_paths, steps, mu, sigma, s0)
    sorted_res = sorted(sim_results)
    var95 = sorted_res[int(0.05 * len(sorted_res))]

    return {
        "scenario": req.scenario,
        "VaR_95":   var95,
        "n_paths":  n_paths
    }
