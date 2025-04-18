import 'dart:async';
import 'dart:math';
import 'dart:ui'; // For ImageFilter

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DeliveryCountdownTimer extends StatefulWidget {
  final Timestamp? deliveryDate;
  final VoidCallback? onDeliveryComplete;
  final bool isHost;
  final VoidCallback? onChangeDate;

  const DeliveryCountdownTimer({
    Key? key,
    required this.deliveryDate,
    this.onDeliveryComplete,
    this.isHost = false,
    this.onChangeDate,
  }) : super(key: key);

  @override
  State<DeliveryCountdownTimer> createState() => _DeliveryCountdownTimerState();
}

class _DeliveryCountdownTimerState extends State<DeliveryCountdownTimer> 
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  Duration _remainingTime = Duration.zero;
  bool _isExpired = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  // Colors based on time remaining
  final Color _farColor = Colors.blue.shade300;
  final Color _mediumColor = Colors.amber.shade300;
  final Color _closeColor = Colors.orange.shade400;
  final Color _urgentColor = Colors.red.shade400;

  @override
  void initState() {
    super.initState();
    
    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start pulsing animation in loop
    _animationController.repeat(reverse: true);
    
    _calculateTimeRemaining();
    
    // Update the countdown every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateTimeRemaining();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    if (widget.deliveryDate == null) {
      setState(() {
        _remainingTime = Duration.zero;
        _isExpired = false;
      });
      return;
    }

    final now = DateTime.now();
    final deliveryDateTime = widget.deliveryDate!.toDate();
    
    if (deliveryDateTime.isBefore(now)) {
      setState(() {
        _remainingTime = Duration.zero;
        _isExpired = true;
      });
      
      // Trigger delivery if we just expired
      if (_isExpired && widget.onDeliveryComplete != null) {
        widget.onDeliveryComplete!();
      }
    } else {
      setState(() {
        _remainingTime = deliveryDateTime.difference(now);
        _isExpired = false;
      });
    }
  }

  Color _getTimerColor() {
    if (_isExpired) return _urgentColor;
    
    final days = _remainingTime.inDays;
    
    if (days > 7) {
      return _farColor;
    } else if (days > 3) {
      return _mediumColor;
    } else if (days > 1) {
      return _closeColor;
    } else {
      return _urgentColor;
    }
  }

  String _formatDate() {
    if (widget.deliveryDate == null) return "No delivery date set";
    return DateFormat.yMMMd().format(widget.deliveryDate!.toDate());
  }

  String _formatTimeRemaining() {
    if (widget.deliveryDate == null) return "";
    if (_isExpired) return "Delivery time!";
    
    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours % 24;
    final minutes = _remainingTime.inMinutes % 60;
    
    if (days > 0) {
      return "$days ${days == 1 ? 'day' : 'days'}, "
          "$hours ${hours == 1 ? 'hour' : 'hours'}";
    } else if (hours > 0) {
      return "$hours ${hours == 1 ? 'hour' : 'hours'}, "
          "$minutes ${minutes == 1 ? 'minute' : 'minutes'}";
    } else {
      return "$minutes ${minutes == 1 ? 'minute' : 'minutes'}";
    }
  }

  double _getCompletionPercentage() {
    if (widget.deliveryDate == null) return 0.0;
    if (_isExpired) return 1.0;
    
    // Calculate total duration from creation to delivery
    final deliveryDateTime = widget.deliveryDate!.toDate();
    final now = DateTime.now();
    
    // Assume a minimum duration of 1 day to avoid division by zero
    final totalDuration = deliveryDateTime.difference(now.subtract(const Duration(days: 7)));
    final elapsedDuration = const Duration(days: 7);
    
    return elapsedDuration.inSeconds / totalDuration.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deliveryDate == null) {
      return SizedBox.shrink();
    }
    
    final timerColor = _getTimerColor();
    final percentage = _getCompletionPercentage();
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _isExpired || _remainingTime.inDays <= 1 
            ? _pulseAnimation.value 
            : 1.0;
            
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: timerColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    timerColor.withOpacity(0.3),
                    timerColor.withOpacity(0.15),
                  ],
                ),
                border: Border.all(
                  color: timerColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delivery header
                  Row(
                    children: [
                      Icon(
                        _isExpired ? Icons.celebration : Icons.schedule,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isExpired ? "Delivery Time!" : "Delivery Countdown",
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      if (widget.isHost && !_isExpired)
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Change"),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: widget.onChangeDate,
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Countdown display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Circular progress
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          children: [
                            // Background circle
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 8,
                                backgroundColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            
                            // Progress circle
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: percentage,
                                strokeWidth: 8,
                                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            
                            // Center content
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isExpired)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 28,
                                    )
                                  else
                                    Text(
                                      _remainingTime.inDays.toString(),
                                      style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 28,
                                      ),
                                    ),
                                  Text(
                                    _isExpired ? "Done" : "days",
                                    style: GoogleFonts.nunito(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Time breakdown
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatTimeRemaining(),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Delivery on: ${_formatDate()}",
                                style: GoogleFonts.nunito(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              if (_isExpired && widget.isHost)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ElevatedButton(
                                    onPressed: widget.onDeliveryComplete,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: timerColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text("Send Now"),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for arc progress indicator
class ArcProgressPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double strokeWidth;

  ArcProgressPainter({
    required this.percentage,
    required this.color,
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2;
    
    // Draw background arc
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
      
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      2 * pi * percentage, // Sweep angle
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
} 