///|
/// コレクション不変条件Analyzer（Phase 2 Enhanced Invariant Detection）
/// 関数シグネチャからコレクション操作を推論し、適切な不変条件を提案する
///

///|
/// コレクション操作の種類
pub enum CollectionOperation {
  Map
  Filter
  Reduce
  Fold
  Sort
  Reverse
  FlatMap
  Zip
  Unzip
  Take
  Drop
  Partition
  GroupBy
  Unknown
}

///|
/// 増強された不変条件提案
pub struct EnhancedInvariant {
  func_name : String
  operation : CollectionOperation
  invariants : Array[String]
  description : String
  examples : Array[String]
}

///|
/// CollectionOperationを文字列に変換
pub fn CollectionOperation::to_string(self : CollectionOperation) -> String {
  match self {
    Map => "Map"
    Filter => "Filter"
    Reduce => "Reduce"
    Fold => "Fold"
    Sort => "Sort"
    Reverse => "Reverse"
    FlatMap => "FlatMap"
    Zip => "Zip"
    Unzip => "Unzip"
    Take => "Take"
    Drop => "Drop"
    Partition => "Partition"
    GroupBy => "GroupBy"
    Unknown => "Unknown"
  }
}

///|
/// 関数名からコレクション操作を推論
pub fn infer_collection_operation(func_name : String) -> CollectionOperation {
  let name_lower = func_name.to_lower()

  // 操作のキーワードマッピング
  if name_lower.contains("map") {
    Map
  } else if name_lower.contains("filter") || name_lower.contains("where") {
    Filter
  } else if name_lower.contains("reduce") {
    Reduce
  } else if name_lower.contains("fold") ||
    name_lower.contains("foldl") ||
    name_lower.contains("foldr") {
    Fold
  } else if name_lower.contains("sort") || name_lower.contains("order") {
    Sort
  } else if name_lower.contains("reverse") {
    Reverse
  } else if name_lower.contains("flat_map") ||
    name_lower.contains("flatmap") ||
    name_lower.contains("bind") {
    FlatMap
  } else if name_lower.contains("zip") {
    Zip
  } else if name_lower.contains("unzip") {
    Unzip
  } else if name_lower.contains("take") || name_lower.contains("first") {
    Take
  } else if name_lower.contains("drop") ||
    name_lower.contains("skip") ||
    name_lower.contains("tail") {
    Drop
  } else if name_lower.contains("partition") || name_lower.contains("split") {
    Partition
  } else if name_lower.contains("group") {
    GroupBy
  } else {
    Unknown
  }
}

///|
/// 操作から推奨される不変条件を生成
pub fn suggest_invariants_for_operation(
  operation : CollectionOperation,
  _func_name : String,
) -> Array[String] {
  match operation {
    Map => ["LengthPreserving", "OrderPreserving", "ElementCountPreserving"]
    Filter => ["LengthDecreasing", "OrderPreserving", "NoDuplicatesInOutput"]
    Reduce => ["AssociativeProperty", "IdentityElement"]
    Fold => ["TypeConsistency", "AccumulatorCorrectness"]
    Sort => ["ContentPreserving", "OrderPreserving", "Stability"]
    Reverse => ["LengthPreserving", "ContentPreserving"]
    FlatMap => ["TypeConsistency", "FlatteningCorrectness"]
    Zip => ["LengthPreserving", "PairAlignment"]
    Unzip => ["LengthPreserving", "PairAlignment"]
    Take => ["LengthDecreasing", "OrderPreserving"]
    Drop => ["LengthDecreasing", "OrderPreserving"]
    Partition => ["LengthPreserving", "DisjointSets", "CompleteCoverage"]
    GroupBy => ["CompleteCoverage", "NonEmptyGroups"]
    Unknown => []
  }
}

///|
/// 操作の説明を生成
pub fn describe_operation(operation : CollectionOperation) -> String {
  match operation {
    Map => "Transforms each element using a function while preserving structure"
    Filter => "Selects elements that satisfy a predicate"
    Reduce => "Combines all elements into a single value"
    Fold => "Traverses elements while accumulating state"
    Sort => "Arranges elements according to an ordering"
    Reverse => "Reverses the order of elements"
    FlatMap => "Maps each element to a collection and flattens the result"
    Zip => "Combines two collections into pairs"
    Unzip => "Separates a collection of pairs into two collections"
    Take => "Selects the first n elements"
    Drop => "Skips the first n elements"
    Partition => "Splits elements into two groups based on a predicate"
    GroupBy => "Groups elements by a key function"
    Unknown => "Unknown operation"
  }
}

///|
/// 操作の例を生成
pub fn examples_for_operation(operation : CollectionOperation) -> Array[String] {
  match operation {
    Map =>
      [
        "map([1, 2, 3], fn(x) { x * 2 }) == [2, 4, 6]", "length(map(xs, f)) == length(xs)",
        "map(xs, id) == xs",
      ]
    Filter =>
      [
        "filter([1, 2, 3, 4], fn(x) { x % 2 == 0 }) == [2, 4]", "length(filter(xs, p)) <= length(xs)",
        "filter(filter(xs, p), q) == filter(xs, fn(x) { p(x) && q(x) })",
      ]
    Reduce =>
      [
        "reduce([1, 2, 3], 0, fn(acc, x) { acc + x }) == 6", "reduce([1, 2, 3], 1, fn(acc, x) { acc * x }) == 6",
      ]
    Fold =>
      [
        "foldl([1, 2, 3], 0, fn(acc, x) { acc + x }) == 6", "foldr([1, 2, 3], 0, fn(x, acc) { x + acc }) == 6",
      ]
    Sort =>
      [
        "sort([3, 1, 2]) == [1, 2, 3]", "is_sorted(sort(xs))", "length(sort(xs)) == length(xs)",
      ]
    Reverse =>
      [
        "reverse([1, 2, 3]) == [3, 2, 1]", "length(reverse(xs)) == length(xs)", "reverse(reverse(xs)) == xs",
      ]
    FlatMap => ["flat_map([[1, 2], [3]], fn(x) { x }) == [1, 2, 3]"]
    Zip =>
      [
        "zip([1, 2], [3, 4]) == [(1, 3), (2, 4)]", "length(zip(xs, ys)) == min(length(xs), length(ys))",
      ]
    Unzip => ["unzip([(1, 2), (3, 4)]) == ([1, 3], [2, 4])"]
    Take => ["take([1, 2, 3, 4], 2) == [1, 2]", "length(take(xs, n)) <= n"]
    Drop =>
      [
        "drop([1, 2, 3, 4], 2) == [3, 4]", "length(drop(xs, n)) == max(0, length(xs) - n)",
      ]
    Partition =>
      [
        "partition([1, 2, 3, 4], fn(x) { x % 2 == 0 }) == ([2, 4], [1, 3])", "length(partition(xs, p).0) + length(partition(xs, p).1) == length(xs)",
      ]
    GroupBy =>
      ["group_by([1, 2, 3, 4], fn(x) { x % 2 }) == {0: [2, 4], 1: [1, 3]}"]
    Unknown => []
  }
}

///|
/// 関数名から増強された不変条件を推論
pub fn infer_enhanced_invariants(func_name : String) -> EnhancedInvariant {
  let operation = infer_collection_operation(func_name)
  let invariants = suggest_invariants_for_operation(operation, func_name)
  let description = describe_operation(operation)
  let examples = examples_for_operation(operation)
  { func_name, operation, invariants, description, examples }
}

///|
/// 複数の関数から増強された不変条件を推論
pub fn infer_enhanced_invariants_for_functions(
  function_names : Array[String],
) -> Array[EnhancedInvariant] {
  let results : Array[EnhancedInvariant] = []
  let mut i = 0
  while i < function_names.length() {
    let func = function_names[i]
    let enhanced = infer_enhanced_invariants(func)
    // 有用な不変条件があるもののみを返す
    if enhanced.invariants.length() > 0 {
      results.push(enhanced)
    }
    i = i + 1
  }
  results
}

///|
/// EnhancedInvariantをPatternCandidateに変換（既存パターンとの統合用）
pub fn enhanced_invariant_to_pattern(
  enhanced : EnhancedInvariant,
) -> PatternCandidate? {
  if enhanced.invariants.length() > 0 {
    // 最初の不変条件をメインのパターンとして使用
    let primary_invariant = enhanced.invariants[0]
    Some(Invariant(enhanced.func_name, primary_invariant))
  } else {
    None
  }
}

///|
/// テスト
test "infer_collection_operation_map" {
  let op = infer_collection_operation("map_values")
  inspect(op.to_string(), content="Map")
  let op2 = infer_collection_operation("transform_map")
  inspect(op2.to_string(), content="Map")
}

///|
test "infer_collection_operation_filter" {
  let op = infer_collection_operation("filter_even")
  inspect(op.to_string(), content="Filter")
  let op2 = infer_collection_operation("where_clause")
  inspect(op2.to_string(), content="Filter")
}

///|
test "infer_collection_operation_sort" {
  let op = infer_collection_operation("quick_sort")
  inspect(op.to_string(), content="Sort")
  let op2 = infer_collection_operation("ordered_list")
  inspect(op2.to_string(), content="Sort")
}

///|
test "suggest_invariants_for_map" {
  let invariants = suggest_invariants_for_operation(Map, "map_values")
  inspect(invariants.length(), content="3")
  inspect(invariants.contains("LengthPreserving"), content="true")
  inspect(invariants.contains("OrderPreserving"), content="true")
}

///|
test "suggest_invariants_for_filter" {
  let invariants = suggest_invariants_for_operation(Filter, "filter_even")
  inspect(invariants.length(), content="3")
  inspect(invariants.contains("LengthDecreasing"), content="true")
  inspect(invariants.contains("OrderPreserving"), content="true")
}

///|
test "infer_enhanced_invariants_structure" {
  let enhanced = infer_enhanced_invariants("map_values")
  inspect(enhanced.func_name, content="map_values")
  inspect(enhanced.operation.to_string(), content="Map")
  inspect(enhanced.invariants.length() > 0, content="true")
  inspect(enhanced.description.length() > 0, content="true")
  inspect(enhanced.examples.length() > 0, content="true")
}

///|
test "infer_enhanced_invariants_for_functions_filters_unknown" {
  let names = ["map_values", "filter_even", "unknown_func"]
  let results = infer_enhanced_invariants_for_functions(names)
  // unknown_func should be filtered out since it has no invariants
  inspect(results.length(), content="2")
  inspect(results[0].func_name, content="map_values")
  inspect(results[1].func_name, content="filter_even")
}

///|
test "enhanced_invariant_to_pattern_integration" {
  let enhanced = infer_enhanced_invariants("map_values")
  let pattern_opt = enhanced_invariant_to_pattern(enhanced)
  match pattern_opt {
    Some(pattern) =>
      match pattern {
        Invariant(func, inv_type) => {
          inspect(func, content="map_values")
          inspect(inv_type, content="LengthPreserving")
        }
        _ => inspect("fail", content="ok")
      }
    None => inspect("fail", content="ok")
  }
}
