// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'singbox_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SingboxRuleImpl _$$SingboxRuleImplFromJson(Map<String, dynamic> json) =>
    _$SingboxRuleImpl(
      ruleSetUrl: json['rule-set-url'] as String?,
      domains: (json['domains'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      ip: json['ip'] as String?,
      port: json['port'] as String?,
      protocol: json['protocol'] as String?,
      network:
          $enumDecodeNullable(_$RuleNetworkEnumMap, json['network']) ??
          RuleNetwork.tcpAndUdp,
      outbound: _ruleOutboundFromJson(json['outbound']),
    );

Map<String, dynamic> _$$SingboxRuleImplToJson(
  _$SingboxRuleImpl instance,
) => <String, dynamic>{
  if (instance.ruleSetUrl case final value?) 'rule-set-url': value,
  if (instance.domains case final value?) 'domains': value,
  if (instance.ip case final value?) 'ip': value,
  if (instance.port case final value?) 'port': value,
  if (instance.protocol case final value?) 'protocol': value,
  if (_ruleNetworkToJson(instance.network) case final value?) 'network': value,
  'outbound': _ruleOutboundToJson(instance.outbound),
};

const _$RuleNetworkEnumMap = {
  RuleNetwork.tcpAndUdp: '',
  RuleNetwork.tcp: 'tcp',
  RuleNetwork.udp: 'udp',
};

// RuleOutbound now uses integer serialization via _ruleOutboundToJson/_ruleOutboundFromJson
