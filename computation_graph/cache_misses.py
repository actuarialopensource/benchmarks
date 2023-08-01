from Cash import cash
from lru import LRU
from model1 import net_premium_pp as net_premium_pp1, pv_net_cf as pv_net_cf1
from model2 import net_premium_pp as net_premium_pp2, pv_net_cf as pv_net_cf2
from model3 import net_premium_pp as net_premium_pp3, pv_net_cf as pv_net_cf3
import json

def write_function_cache_misses(function, filename):
    cash.reset(lambda: LRU(1))
    function()
    with open(filename, 'w') as f:
        json.dump(cash.cache_misses, f, indent=4, sort_keys=True)

write_function_cache_misses(net_premium_pp1, 'net_premium_pp1_misses.json')
write_function_cache_misses(net_premium_pp2, 'net_premium_pp2_misses.json')
write_function_cache_misses(net_premium_pp3, 'net_premium_pp3_misses.json')

write_function_cache_misses(pv_net_cf1, 'pv_net_cf1_misses.json')
write_function_cache_misses(pv_net_cf2, 'pv_net_cf2_misses.json')
write_function_cache_misses(pv_net_cf3, 'pv_net_cf3_misses.json')