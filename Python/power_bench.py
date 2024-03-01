import timeit
import torch

# Define m outside of timeit for proper scope
m = torch.rand(10000, 241, dtype=torch.float64)

result = timeit.time('1 - (1 - m) ** (1 / 12)', number=10)
average_result = result / 10
print(f'Average time: {average_result:.3f} seconds')

python -m timeit  -s "import torch;m = torch.rand(10000, 241, dtype=torch.float64)" "1 - (1 - m) ** (1 / 12)"