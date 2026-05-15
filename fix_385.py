# Fix for Issue #385 - Value Compass Enhancement
from typing import List
from dataclasses import dataclass

@dataclass
class ValueScore:
    category: str
    score: float
    weight: float

    @property
    def weighted_score(self) -> float:
        return self.score * self.weight

def calculate_composite(scores: List[ValueScore]) -> float:
    if not scores:
        return 0.0
    total_weight = sum(s.weight for s in scores)
    if total_weight == 0:
        return 0.0
    return sum(s.weighted_score for s in scores) / total_weight

def normalize_scores(scores: List[float]) -> List[float]:
    if not scores:
        return []
    min_val, max_val = min(scores), max(scores)
    range_val = max_val - min_val
    if range_val == 0:
        return [0.5] * len(scores)
    return [(s - min_val) / range_val for s in scores]
