import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:revitool/core/security/security_service.dart';
import 'package:revitool/utils.dart';

class SecurityCommand extends Command<String> {
  static final _securityService = SecurityService();
  String get tag => "[Security - Defender]";

  @override
  String get description => '[$tag] A command to manage Windows Defender';

  @override
  String get name => 'defender';

  SecurityCommand() {
    argParser.addCommand('status');
    argParser.addCommand('enable').addCommand("--force");
    argParser.addCommand('disable').addCommand("--force");
  }

  @override
  FutureOr<String>? run() async {
    final bool isForce = argResults?.command?.command?.name == '--force';
    switch (argResults?.command?.name) {
      case 'enable':
        if (!isForce && _securityService.statusDefender) {
          stdout.writeln('$tag Windows Defender is already enabled');
          exit(0);
        }
        await _securityService.enableDefender();
        break;
      case 'disable':
        await _disableDefender(isForce);
        break;
      default:
        stdout.writeln('''
Defender Status: ${_securityService.statusDefender.toString()}
Virus and Threat Protections Status: ${_securityService.statusDefenderProtections.toString()}
''');
    }
    exit(0);
  }

  Future<void> _disableDefender(bool isForce) async {
    if (!isForce && !_securityService.statusDefender) {
      stdout.writeln('$tag Windows Defender is already disabled');
      exit(0);
    }

    if (!isProcessRunning('explorer.exe')) {
      await Process.run('explorer.exe', const []);
      await Future.delayed(const Duration(seconds: 5));
    }

    stdout.writeln('$tag Disabling Windows Defender...');

    stdout.writeln(
      '$tag Checking if Virus and Threat Protections are enabled...',
    );
    int count = 0;
    while (_securityService.statusDefenderProtections) {
      if (count > 10) {
        stderr.writeln('$tag Unable to disable Defender. Exiting...');
        exit(1);
      }

      if (!_securityService.statusDefenderProtectionTamper) {
        await runPSCommand(
          'Set-MpPreference -DisableRealtimeMonitoring \$true',
        );
        break;
      }

      stdout.writeln('$tag Please disable Realtime and Tamper Protections');
      await _securityService.openDefenderThreatSettings();

      await Future.delayed(const Duration(seconds: 7));
      count++;
    }
    await Process.run('taskkill', ['/f', '/im', 'SecHealthUI.exe']);

    try {
      await _securityService.disableDefender();
    } on Exception catch (e) {
      stderr.writeln('$tag Error disabling Windows Defender: ${e.toString()}');
      exit(1);
    }
  }
}
