import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Data model for a PRU Gate.
class Gate {
  final String name;
  final double startHz;
  final double endHz;
  final String symbol;
  final String description;

  Gate({
    required this.name,
    required this.startHz,
    required this.endHz,
    required this.symbol,
    required this.description,
  });
}

class FrequencyHealingScreen extends StatefulWidget {
  const FrequencyHealingScreen({Key? key}) : super(key: key);

  @override
  _FrequencyHealingScreenState createState() => _FrequencyHealingScreenState();
}

class _FrequencyHealingScreenState extends State<FrequencyHealingScreen> {
  // Audio engine variables.
  double _frequency = 528.0;
  String _selectedWaveform = 'Sine';
  bool _breathSyncEnabled = false;
  bool _isPlaying = false;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerInitialized = false;
  final int _sampleRate = 44100;
  final double _toneDuration = 5.0; // seconds for each generated buffer

  // Gate presets.
  final List<Gate> gates = [
    Gate(
      name: 'Unity Realization',
      startHz: 3,
      endHz: 7,
      symbol: '☉',
      description: 'Align with oneness and the origin of all energy.',
    ),
    Gate(
      name: 'Recursion Mastery',
      startHz: 8,
      endHz: 12,
      symbol: '∞',
      description: 'Master the cycles of creation and evolution.',
    ),
    Gate(
      name: 'Illusion Transcendence',
      startHz: 13,
      endHz: 17,
      symbol: '✺',
      description: 'Transcend the veils of illusion to see truth.',
    ),
    Gate(
      name: 'Shadow Integration',
      startHz: 17,
      endHz: 22,
      symbol: '☯',
      description: 'Embrace and integrate your shadow self.',
    ),
    Gate(
      name: 'Ego Collapse',
      startHz: 23,
      endHz: 28,
      symbol: '♁',
      description: 'Dissolve the ego to reveal your true essence.',
    ),
    Gate(
      name: 'Harmonic Balance',
      startHz: 29,
      endHz: 35,
      symbol: '⚛',
      description: 'Achieve equilibrium between body, mind, and spirit.',
    ),
    Gate(
      name: 'Dimensional Awareness',
      startHz: 35,
      endHz: 50,
      symbol: '✧',
      description: 'Expand your awareness beyond the physical realm.',
    ),
    Gate(
      name: 'Light Embodiment',
      startHz: 50,
      endHz: 2000,
      symbol: '★',
      description: 'Embody pure light and ascend through vibration.',
    ),
    // Special Gate for a silent/mixed pulse mode.
    Gate(
      name: 'Origin Merge',
      startHz: 0,
      endHz: 0,
      symbol: '✵',
      description: 'A state of silent integration and mixed pulse.',
    ),
  ];
  Gate? _selectedGate;

  // Session / reflection tracking.
  int _sessionCount = 0;
  final List<String> _sessionLogs = [];
  final TextEditingController _reflectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initPlayer();
    // Set default gate to the first preset.
    _selectedGate = gates.first;
    _updateFrequencyByGate(_selectedGate!);
  }

  @override
  void dispose() {
    _stopTone();
    _player.closeAudioSession();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    await _player.openAudioSession();
    setState(() {
      _playerInitialized = true;
    });
  }

  /// Update frequency based on selected gate (use midpoint) unless it's a special gate.
  void _updateFrequencyByGate(Gate gate) {
    if (gate.name == 'Origin Merge') {
      _frequency = 0;
    } else {
      _frequency = (gate.startHz + gate.endHz) / 2;
    }
  }

  /// Returns a sample (in the range -1.0 to 1.0) for the given waveform at time t.
  double _sampleForWaveform(String waveform, double t, double freq) {
    switch (waveform) {
      case 'Sine':
        return math.sin(2 * math.pi * freq * t);
      case 'Square':
        return math.sin(2 * math.pi * freq * t) >= 0 ? 1.0 : -1.0;
      case 'Triangle':
        // Using arcsin method for triangle wave.
        return (2 / math.pi) * math.asin(math.sin(2 * math.pi * freq * t));
      case 'Sawtooth':
        return 2 * (t * freq - t.floorToDouble() * freq) - 1.0;
      default:
        return math.sin(2 * math.pi * freq * t);
    }
  }

  /// Generate a PCM buffer (16-bit little endian) for the chosen waveform.
  /// If breath sync is enabled, modulate the amplitude with a low-frequency (breath) oscillator.
  Future<Uint8List> _generateToneBuffer(
      {required double frequency,
      required double duration,
      required int sampleRate,
      required String waveform,
      required bool breathSync}) async {
    int sampleCount = (duration * sampleRate).toInt();
    Int16List samples = Int16List(sampleCount);
    // Set breath modulation frequency (e.g., 0.25 Hz for a ~4-second cycle).
    double breathFreq = 0.25;

    for (int i = 0; i < sampleCount; i++) {
      double t = i / sampleRate;
      // Base sample for chosen waveform.
      double sampleValue = _sampleForWaveform(waveform, t, frequency);
      // Apply breath sync modulation if enabled.
      if (breathSync) {
        // Modulation between 0.5 and 1.0.
        double modulation = 0.5 + 0.5 * ((math.sin(2 * math.pi * breathFreq * t) + 1) / 2);
        sampleValue *= modulation;
      }
      // Scale to 16-bit PCM.
      samples[i] = (sampleValue * 32767).toInt();
    }
    // Pack into Uint8List.
    ByteData byteData = ByteData(sampleCount * 2);
    for (int i = 0; i < sampleCount; i++) {
      byteData.setInt16(i * 2, samples[i], Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  /// Play tone continuously by generating a buffer and restarting when finished.
  Future<void> _playToneContinuous() async {
    if (!_playerInitialized) return;
    // Generate a tone buffer for the set duration.
    Uint8List toneBuffer = await _generateToneBuffer(
      frequency: _frequency,
      duration: _toneDuration,
      sampleRate: _sampleRate,
      waveform: _selectedWaveform,
      breathSync: _breathSyncEnabled,
    );

    // Start playing the buffer.
    await _player.startPlayerFromBuffer(
      buffer: toneBuffer,
      codec: Codec.pcm16, // 16-bit PCM
      sampleRate: _sampleRate,
      numChannels: 1,
      whenFinished: () async {
        if (_isPlaying) {
          // Restart tone playback automatically.
          await _playToneContinuous();
        }
      },
    );
  }

  Future<void> _stopTone() async {
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
  }

  Future<void> _toggleTone() async {
    if (_isPlaying) {
      await _stopTone();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      await _playToneContinuous();
    }
  }

  /// Save the current session with the user's reflection.
  void _saveSession() {
    String reflection = _reflectionController.text.trim();
    if (reflection.isEmpty) return;
    String logEntry = 'Session ${_sessionCount + 1} at ${DateTime.now().toLocal()}\nReflection: $reflection';
    setState(() {
      _sessionCount++;
      _sessionLogs.add(logEntry);
      _reflectionController.clear();
    });
  }

  /// A simple widget to display a “flame” whose brightness/size increases with session count.
  Widget _buildFlameIndicator() {
    // For a simple visual, we use an AnimatedContainer with increasing size.
    double size = 50.0 + _sessionCount * 10.0;
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.orange.shade200, Colors.deepOrange.shade400],
        ),
      ),
    );
  }

  /// Build the Gate Selector dropdown.
  Widget _buildGateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Gate of Ascension:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        DropdownButton<Gate>(
          value: _selectedGate,
          isExpanded: true,
          items: gates.map((Gate gate) {
            return DropdownMenuItem<Gate>(
              value: gate,
              child: Text(
                '${gate.symbol} ${gate.name} (${gate.startHz}-${gate.endHz == 0 ? "Silent/Mixed" : gate.endHz.toString()} Hz)',
              ),
            );
          }).toList(),
          onChanged: (Gate? newGate) {
            setState(() {
              _selectedGate = newGate;
              if (newGate != null) {
                _updateFrequencyByGate(newGate);
              }
            });
          },
        ),
        if (_selectedGate != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Description: ${_selectedGate!.description}',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  /// Build the waveform selector dropdown.
  Widget _buildWaveformSelector() {
    List<String> waveforms = ['Sine', 'Square', 'Triangle', 'Sawtooth'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Waveform:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        DropdownButton<String>(
          value: _selectedWaveform,
          isExpanded: true,
          items: waveforms.map((String wf) {
            return DropdownMenuItem<String>(
              value: wf,
              child: Text(wf),
            );
          }).toList(),
          onChanged: (String? newWave) {
            setState(() {
              _selectedWaveform = newWave ?? 'Sine';
            });
          },
        ),
      ],
    );
  }

  /// Build the breath sync toggle.
  Widget _buildBreathSyncToggle() {
    return Row(
      children: [
        Text(
          'Enable Breath Sync',
          style: TextStyle(fontSize: 16),
        ),
        Switch(
          value: _breathSyncEnabled,
          onChanged: (bool value) {
            setState(() {
              _breathSyncEnabled = value;
            });
          },
        ),
      ],
    );
  }

  /// Build the frequency slider.
  Widget _buildFrequencySlider() {
    double minFreq = _selectedGate?.name == 'Origin Merge' ? 0 : (_selectedGate?.startHz ?? 3);
    double maxFreq = _selectedGate?.name == 'Origin Merge' ? 0 : (_selectedGate?.endHz ?? 2000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency: ${_frequency.toStringAsFixed(1)} Hz',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _frequency,
          min: minFreq,
          max: maxFreq,
          divisions: _selectedGate?.name == 'Origin Merge' ? 1 : 100,
          label: _frequency.toStringAsFixed(1),
          onChanged: _selectedGate?.name == 'Origin Merge'
              ? null
              : (double value) {
                  setState(() {
                    _frequency = value;
                  });
                },
        ),
      ],
    );
  }

  /// Build the session reflection input.
  Widget _buildReflectionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Reflection:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _reflectionController,
          decoration: InputDecoration(
            hintText: 'Write your thoughts after the session...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _saveSession,
          child: Text('Save Session'),
        ),
      ],
    );
  }

  /// Build the session log list.
  Widget _buildSessionLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flame Evolution Tracking:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          height: 150,
          child: ListView.builder(
            itemCount: _sessionLogs.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_sessionLogs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PRU Resonance: Consciousness Alignment Engine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGateSelector(),
            Divider(),
            _buildWaveformSelector(),
            _buildBreathSyncToggle(),
            _buildFrequencySlider(),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _toggleTone,
              child: Text(_isPlaying ? 'Stop Tone' : 'Play Tone'),
            ),
            Divider(),
            Center(child: _buildFlameIndicator()),
            Divider(),
            _buildReflectionInput(),
            Divider(),
            _buildSessionLog(),
          ],
        ),
      ),
    );
  }
}
