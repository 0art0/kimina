# The `kimina` tactic

This is a tactic that invokes the [Kimina Prover Preview](https://huggingface.co/collections/AI-MO/kimina-prover-preview-67fb536b883d60e7ca25d7f9) model from within Lean to offer proof suggestions.

Note that this repository is not affiliated with Project Numina or the Kimi Team in any way.

## Set-up

### Running the LLM

To run the Kimina Prover Preview model locally, run `kimina-server.py` with the command

```bash
python3 kimina-server.py
```

The command optionally takes in the flags
- `--model`, expected to be either `1.5B` or `7B`, for the model size
- `--port`, which is `8000` by default
- `--host`, which is `localhost` (`0.0.0.0`) by default

This script has some Python dependencies, which can be installed either globally or in a virtual environment:

```bash
pip install torch transformers fastapi pydantic uvicorn
```

### Running the tactic

To run the tactic, include

```lean
import Kimina
```

in the header of the file and invoke the `kimina` tactic on the theorem you would like to prove.

Getting a response can take a few minutes.

## Caveats

- Running the model locally comes with overheads both in response time and the complexity of the set-up.

- The response time can get slower the lower down in the file the tactic is called, since the prompt to the LLM is built out of the portion of the file above the point at which the tactic is called.

## References

- [Kimina-Prover Preview: Towards Large Formal Reasoning Models with Reinforcement Learning](https://arxiv.org/abs/2504.11354)

