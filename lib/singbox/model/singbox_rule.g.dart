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
      processNames: (json['process-names'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      network:
          $enumDecodeNullable(_$RuleNetworkEnumMap, json['network']) ??
          RuleNetwork.tcpAndUdp,
      outbound:
          $enumDecodeNullable(_$RuleOutboundEnumMap, json['outbound']) ??
          RuleOutbound.proxy,
    );

Map<String, dynamic> _$$SingboxRuleImplToJson(
  _$SingboxRuleImpl instance,
) => <String, dynamic>{
  if (instance.ruleSetUrl case final value?) 'rule-set-url': value,
  if (instance.domains case final value?) 'domains': value,
  if (instance.ip case final value?) 'ip': value,
  if (instance.port case final value?) 'port': value,
  if (instance.protocol case final value?) 'protocol': value,
  if (instance.processNames case final value?) 'process-names': value,
  if (_ruleNetworkToJson(instance.network) case final value?) 'network': value,
  'outbound': _ruleOutboundToJson(instance.outbound),
};

const _$RuleNetworkEnumMap = {
  RuleNetwork.tcpAndUdp: '',
  RuleNetwork.tcp: 'tcp',
  RuleNetwork.udp: 'udp',
};

const _$RuleOutboundEnumMap = {
  RuleOutbound.proxy: 'proxy',
  RuleOutbound.bypass: 'bypass',
  RuleOutbound.block: 'block',
};
