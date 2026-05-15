# Fix #385
from dataclasses import dataclass
@dataclass
class VS:
    cat: str; score: float; weight: float

def comp(s): return sum(x.score*x.weight for x in s)/max(sum(x.weight for x in s),1)
