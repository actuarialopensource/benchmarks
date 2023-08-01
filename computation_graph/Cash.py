from collections import defaultdict
from functools import wraps

# classes
class Cash:
    def __init__(self, Cache):
        self.reset(Cache)

    def reset(self, Cache):
        self.caches = defaultdict(lambda: Cache())
        self.stack = []
        self.graph = defaultdict(lambda: defaultdict(int))
        self.cache_misses = defaultdict(int)

    def __call__(self, func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            key = args
            if key not in self.caches[func.__name__]:
                node = f"{func.__name__}{key}"
                self.cache_misses[node] += 1
                if self.stack:
                    self.graph[self.stack[-1]][node] += 1
                self.stack.append(node)
                self.caches[func.__name__][key] = func(*args, **kwargs)
                self.stack.pop()
            return self.caches[func.__name__][key]

        return wrapper

cash = Cash(dict)

max_proj_len = 12 * 20 + 1
