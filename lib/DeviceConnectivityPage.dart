import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceConnectivityPage extends StatefulWidget {
  const DeviceConnectivityPage({super.key});

  @override
  _DeviceConnectivityPageState createState() => _DeviceConnectivityPageState();
}

class _DeviceConnectivityPageState extends State<DeviceConnectivityPage> {
  bool bluetoothEnabled = false;
  List<ScanResult> scanResults = [];
  List<BluetoothDevice> connectedDevices = [];

  StreamSubscription<BluetoothAdapterState>? adapterStateSub;
  StreamSubscription<List<ScanResult>>? scanResultsSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        bluetoothEnabled = state == BluetoothAdapterState.on;
      });
      if (bluetoothEnabled) {
        _getConnectedDevices();
      }
    });
  }

  void _getConnectedDevices() {
    setState(() {
      connectedDevices = FlutterBluePlus.connectedDevices;
    });
  }

  Future<void> _scanForDevices() async {
    setState(() => scanResults = []);
    scanResultsSub?.cancel();
    scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results);
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  String _deviceName(BluetoothDevice d) =>
      d.platformName.isNotEmpty ? d.platformName : '(unknown device)';

  @override
  void dispose() {
    adapterStateSub?.cancel();
    scanResultsSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Device Connectivity'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Bluetooth',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                const Spacer(),
                Switch(
                  value: bluetoothEnabled,
                  onChanged: (val) async {
                    if (val) {
                      try {
                        await FlutterBluePlus.turnOn();
                      } catch (_) {}
                    } else {
                      setState(() => bluetoothEnabled = false);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: bluetoothEnabled ? _scanForDevices : null,
              child: const Text('Scan for Devices'),
            ),
            const SizedBox(height: 16),
            const Text('Available Devices',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            ...scanResults.map((r) => ListTile(
                  title: Text(_deviceName(r.device),
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(r.device.remoteId.str,
                      style: const TextStyle(color: Colors.white54)),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await r.device.connect();
                      _getConnectedDevices();
                    },
                    child: const Text('Connect'),
                  ),
                )),
            const SizedBox(height: 16),
            const Text('Connected Devices',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            ...connectedDevices.map((d) => ListTile(
                  title: Text(_deviceName(d),
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(d.remoteId.str,
                      style: const TextStyle(color: Colors.white54)),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await d.disconnect();
                      _getConnectedDevices();
                    },
                    child: const Text('Disconnect'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
