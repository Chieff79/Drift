import 'package:freezed_annotation/freezed_annotation.dart';

part 'singbox_rule.freezed.dart';
part 'singbox_rule.g.dart';

@freezed
class SingboxRule with _$SingboxRule {
  const SingboxRule._();

  @JsonSerializable(fieldRename: FieldRename.kebab, includeIfNull: false)
  const factory SingboxRule({
    String? ruleSetUrl,
    List<String>? domains,
    String? ip,
    String? port,
    String? protocol,
    @JsonKey(toJson: _ruleNetworkToJson) @Default(RuleNetwork.tcpAndUdp) RuleNetwork network,
    @JsonKey(toJson: _ruleOutboundToJson) @Default(RuleOutbound.proxy) RuleOutbound outbound,
  }) = _SingboxRule;

  factory SingboxRule.fromJson(Map<String, dynamic> json) => _$SingboxRuleFromJson(json);
}

/// Returns null for tcpAndUdp (omitted from JSON) to avoid
/// Go unmarshal error on empty string for config.Network type
String? _ruleNetworkToJson(RuleNetwork network) =>
    network == RuleNetwork.tcpAndUdp ? null : network.key;

enum RuleOutbound { proxy, bypass, block }

/// Serialize outbound as integer matching Go's config.Outbound enum:
/// proxy=0, direct=1, direct_with_fragment=2, block=3
int _ruleOutboundToJson(RuleOutbound outbound) => switch (outbound) {
      RuleOutbound.proxy => 0,
      RuleOutbound.bypass => 1,
      RuleOutbound.block => 3,
    };

/// Deserialize outbound from integer or string
RuleOutbound _ruleOutboundFromJson(dynamic value) {
  if (value == null) return RuleOutbound.proxy;
  if (value is int) {
    return switch (value) {
      0 => RuleOutbound.proxy,
      1 => RuleOutbound.bypass,
      3 => RuleOutbound.block,
      _ => RuleOutbound.proxy,
    };
  }
  // fallback: try string
  return RuleOutbound.values.firstWhere(
    (e) => e.name == value.toString(),
    orElse: () => RuleOutbound.proxy,
  );
}

@JsonEnum(valueField: 'key')
enum RuleNetwork {
  tcpAndUdp(""),
  tcp("tcp"),
  udp("udp");

  const RuleNetwork(this.key);

  final String? key;
}
