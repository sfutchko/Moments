import 'dart:math';
import 'package:flutter/material.dart';

// A reusable confetti animation widget that can be used for celebratory moments
class ConfettiCelebration extends StatefulWidget {
  final bool isPlaying;
  final int particleCount;
  final Duration duration;
  
  const ConfettiCelebration({
    Key? key,
    this.isPlaying = true,
    this.particleCount = 50,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);
  
  @override
  State<ConfettiCelebration> createState() => _ConfettiCelebrationState();
}

class _ConfettiCelebrationState extends State<ConfettiCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<ConfettiParticle> _particles;
  
  final Random _random = Random();
  
  // Colors for confetti particles
  final List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
  ];
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    _particles = List.generate(
      widget.particleCount,
      (_) => _createParticle(),
    );
    
    if (widget.isPlaying) {
      _controller.forward();
    }
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        _controller.forward();
        
        // Regenerate particles
        setState(() {
          _particles = List.generate(
            widget.particleCount,
            (_) => _createParticle(),
          );
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(ConfettiCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.stop();
      }
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  ConfettiParticle _createParticle() {
    final color = _colors[_random.nextInt(_colors.length)];
    final size = _random.nextDouble() * 10 + 5;
    final position = Offset(
      _random.nextDouble() * MediaQuery.of(context).size.width,
      -size, // Start from top of screen
    );
    final speed = _random.nextDouble() * 300 + 200;
    final angle = _random.nextDouble() * pi / 2 - pi / 4; // -45 to +45 degrees
    
    return ConfettiParticle(
      color: color,
      position: position,
      size: size,
      speed: speed,
      angle: angle,
      rotation: _random.nextDouble() * 2 * pi, // Random rotation
      rotationSpeed: _random.nextDouble() * 5 - 2.5, // Random rotation speed
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

// Data class for confetti particle
class ConfettiParticle {
  final Color color;
  final Offset position;
  final double size;
  final double speed;
  final double angle;
  final double rotation;
  final double rotationSpeed;
  
  ConfettiParticle({
    required this.color,
    required this.position,
    required this.size,
    required this.speed,
    required this.angle,
    required this.rotation,
    required this.rotationSpeed,
  });
  
  // Calculate position at a given time
  Offset positionAt(double time, Size canvasSize) {
    final x = position.dx + cos(angle) * speed * time;
    final y = position.dy + sin(angle) * speed * time + 400 * time * time; // Add gravity
    
    return Offset(
      x.clamp(0.0, canvasSize.width),
      y.clamp(-100.0, canvasSize.height + 100),
    );
  }
  
  // Calculate rotation at a given time
  double rotationAt(double time) {
    return rotation + rotationSpeed * time;
  }
}

// Custom painter for confetti animation
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;
  
  ConfettiPainter({
    required this.particles,
    required this.progress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final position = particle.positionAt(progress, size);
      final rotation = particle.rotationAt(progress);
      
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotation);
      
      final path = Path();
      final shape = Random().nextInt(3);
      
      if (shape == 0) {
        // Rectangle
        path.addRect(Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.7,
        ));
      } else if (shape == 1) {
        // Circle
        path.addOval(Rect.fromCircle(
          center: Offset.zero,
          radius: particle.size / 2,
        ));
      } else {
        // Triangle
        path.moveTo(0, -particle.size / 2);
        path.lineTo(particle.size / 2, particle.size / 2);
        path.lineTo(-particle.size / 2, particle.size / 2);
        path.close();
      }
      
      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - progress * 0.5)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
} 