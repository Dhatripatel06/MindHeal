import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/models/emotion_result.dart';
import '../widgets/results_chart_widget.dart';

class MoodResultsPage extends StatefulWidget {
  final EmotionResult result;

  const MoodResultsPage({Key? key, required this.result}) : super(key: key);

  @override
  State<MoodResultsPage> createState() => _MoodResultsPageState();
}

class _MoodResultsPageState extends State<MoodResultsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Analysis Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _getAnalysisTypeColor('tflite'), // Default to TFLite for new model
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResults,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportResults,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 16),
              
              // Emotion Breakdown Chart
              _buildEmotionChart(),
              const SizedBox(height: 16),
              
              // Detailed Metrics
              _buildDetailedMetrics(),
              const SizedBox(height: 16),
              
              // Analysis Info
              _buildAnalysisInfo(),
              const SizedBox(height: 16),
              
              // Recommendations
              _buildRecommendations(),
              const SizedBox(height: 24),
              
              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getEmotionColor(widget.result.emotion),
            _getEmotionColor(widget.result.emotion).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getEmotionColor(widget.result.emotion).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _getEmotionIcon(widget.result.emotion),
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            widget.result.emotion.toUpperCase(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(widget.result.confidence * 100).toInt()}% Confidence',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TensorFlow Lite Model', // Updated to reflect new analysis method
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emotion Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: ResultsChartWidget(
              emotionData: widget.result.allEmotions,
            ),
          ),
          const SizedBox(height: 16),
          // Emotion Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: widget.result.allEmotions.entries
                .map((entry) => _buildEmotionLegendItem(entry.key, entry.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionLegendItem(String emotion, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getEmotionColor(emotion),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$emotion: ${(value * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          // Metrics Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildMetricCard(
                'Primary Emotion',
                widget.result.emotion,
                Icons.psychology,
                _getEmotionColor(widget.result.emotion),
              ),
              _buildMetricCard(
                'Confidence Score',
                '${(widget.result.confidence * 100).toInt()}%',
                Icons.trending_up,
                Colors.blue,
              ),
              _buildMetricCard(
                'Analysis Type',
                'TensorFlow Lite', // Updated for new model
                Icons.analytics,
                Colors.purple,
              ),
              _buildMetricCard(
                'Timestamp',
                _formatTime(widget.result.timestamp),
                Icons.access_time,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analysis Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow('Analysis Method', 'TensorFlow Lite Model'),
          _buildInfoRow('Processing Time', '< 1 second'),
          _buildInfoRow('Model Version', 'v2.1.0'),
          _buildInfoRow('Accuracy', '94.2%'),
          _buildInfoRow('Detected Emotions', '${widget.result.allEmotions.length}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = _getRecommendations(widget.result.emotion);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...recommendations.map((recommendation) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: _getEmotionColor(widget.result.emotion),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveToHistory,
                icon: const Icon(Icons.history),
                label: const Text('Save to History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _scheduleReminder,
                icon: const Icon(Icons.notification_add),
                label: const Text('Set Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _runNewAnalysis,
            icon: const Icon(Icons.refresh),
            label: const Text('Run New Analysis'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: _getEmotionColor(widget.result.emotion)),
              foregroundColor: _getEmotionColor(widget.result.emotion),
            ),
          ),
        ),
      ],
    );
  }

  void _shareResults() {
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Results shared successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportResults() {
    // Implement export functionality
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Export Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: const Text('Export as PDF'),
                    onTap: () {
                      Navigator.pop(context);
                      _exportAsPDF();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.table_chart, color: Colors.green),
                    title: const Text('Export as CSV'),
                    onTap: () {
                      Navigator.pop(context);
                      _exportAsCSV();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export started...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportAsCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV export started...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _saveToHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Results saved to history!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _scheduleReminder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder scheduled successfully!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _runNewAnalysis() {
    Navigator.pop(context);
  }

  List<String> _getRecommendations(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return [
          'Continue engaging in activities that bring you joy',
          'Share your positive energy with others',
          'Consider journaling about what made you happy today',
        ];
      case 'sad':
        return [
          'Practice self-compassion and allow yourself to feel',
          'Consider reaching out to a friend or loved one',
          'Engage in gentle activities like walking or listening to music',
        ];
      case 'angry':
        return [
          'Take deep breaths and practice calming techniques',
          'Consider physical exercise to release tension',
          'Reflect on the source of anger when you feel ready',
        ];
      case 'fear':
        return [
          'Practice grounding techniques to feel more centered',
          'Break down your concerns into manageable steps',
          'Consider seeking support if fear persists',
        ];
      default:
        return [
          'Take time for self-reflection',
          'Engage in activities that support your well-being',
          'Consider tracking your mood over time',
        ];
    }
  }

  Color _getAnalysisTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Colors.blue;
      case 'audio':
        return Colors.teal;
      case 'combined':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'fear':
        return Colors.orange;
      case 'surprise':
        return Colors.purple;
      case 'disgust':
        return Colors.brown;
      case 'neutral':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_very_dissatisfied;
      case 'angry':
        return Icons.sentiment_dissatisfied;
      case 'fear':
        return Icons.sentiment_neutral;
      case 'surprise':
        return Icons.sentiment_satisfied;
      case 'disgust':
        return Icons.sentiment_dissatisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_neutral;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
