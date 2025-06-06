import argparse

def main():
    parser = argparse.ArgumentParser(description="Term ME model runner")
    parser.add_argument("--multiplier", type=int, default=100, help="Multiplier for model points")
    # add an argument that must be either "torch_recursive" or "jax_iterative"
    parser.add_argument("--model", type=str, default="jax_iterative", choices=["torch_recursive", "jax_iterative"], help="Model to run")
    args = parser.parse_args()

    multiplier = args.multiplier

    if args.model == "torch_recursive":
        from term_me_recursive_pytorch import time_recursive_PyTorch # having both imports at top level gave a jax error?
        time_recursive_PyTorch(multiplier)
    elif args.model == "jax_iterative":
        from term_me_iterative_jax import time_iterative_jax
        time_iterative_jax(multiplier) 
    else:
        raise ValueError("Invalid model")

if __name__ == "__main__":
    main()