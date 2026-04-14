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
    @Default(RuleOutbound.proxy) RuleOutbound outbound,
  }) = _SingboxRule;

  factory SingboxRule.fromJson(Map<String, dynamic> json) => _$SingboxRuleFromJson(json);
}

/// Returns null for tcpAndUdp (omitted from JSON) to avoid
/// Go unmarshal error on empty string for config.Network type
String? _ruleNetworkToJson(RuleNetwork network) =>
    network == RuleNetwork.tcpAndUdp ? null : network.key;

enum RuleOutbound { proxy, bypass, block }

@JsonEnum(valueField: 'key')
enum RuleNetwork {
  tcpAndUdp(""),
  tcp("tcp"),
  udp("udp");

  const RuleNetwork(this.key);

  final String? key;
}
