import Kimina.Querying

open Lean Elab Core

def main : IO Unit := do
  EIO.toIO (fun _ ↦ IO.userError "Failed to serve Kimina Prover Preview model.") <|
  CoreM.run' Kimina.serveModel { fileName := default, fileMap := default } { env := ← mkEmptyEnvironment }
