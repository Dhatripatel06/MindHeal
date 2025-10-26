// File: lib/features/mood_detection/presentation/pages/mood_results_page.dart
// Fetched from: uploaded:dhatripatel06/mindheal/MindHeal-7d106854c363e04880dc09100a29f774898d294f/lib/features/mood_detection/presentation/pages/mood_results_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Remove or comment out share_plus if no longer needed anywhere
// import 'package:share_plus/share_plus.dart';
import '../../data/models/emotion_result.dart'; //
import '../providers/image_detection_provider.dart'; //
import '../../../../core/utils/emotion_utils.dart'; //

class MoodResultsPage extends StatelessWidget {
  final EmotionResult emotionResult; //
  final String? imagePath; //

  const MoodResultsPage({
    super.key,
    required this.emotionResult,
    this.imagePath,
  });


  @override
  Widget build(BuildContext context) {
    // Access the provider but don't listen here if changes are handled by Consumers below
    final provider = Provider.of<ImageDetectionProvider>(context, listen: false);

    // --- NEW: Ensure provider's current result matches this page's result ---
    // This is important if the user navigates here directly after detection
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (provider.currentResult != emotionResult) {
    //      // You might need a method in the provider like:
    //      // provider.setStaticResultForAdvice(emotionResult);
    //      // Or ensure fetchAdvice can take the mood directly.
    //      // For now, we assume the user flow sets the provider's currentResult correctly before navigating here.
    //      print("Warning: Provider's currentResult might differ from MoodResultsPage emotionResult.");
    //   }
    // });
    // --- END NEW ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Analysis Result'), //
        backgroundColor: EmotionUtils.getEmotionColor(emotionResult.emotion).withOpacity(0.8), //
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), //
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imagePath != null) //
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ClipRRect(
                   borderRadius: BorderRadius.circular(15.0),
                   child: Image.file(
                      File(imagePath!),
                      height: 250,
                      fit: BoxFit.cover,
                   ),
                ),
              ),

             _buildResultCard(context, provider), // Pass provider

            const SizedBox(height: 20),

             ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Analyze Another'),
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, ImageDetectionProvider provider) {
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(20),
         boxShadow: [
           BoxShadow(
             color: Colors.grey.withOpacity(0.1),
             spreadRadius: 2,
             blurRadius: 5,
             offset: const Offset(0, 3),
           ),
         ],
       ),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           // Emotion Display
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(
                 EmotionUtils.getEmotionIcon(emotionResult.emotion), // Use getEmotionIcon
                 size: 48,
                 color: EmotionUtils.getEmotionColor(emotionResult.emotion),
               ),
               const SizedBox(width: 20),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     emotionResult.emotion.toUpperCase(), //
                     style: TextStyle(
                       fontSize: 30,
                       fontWeight: FontWeight.bold,
                       color: EmotionUtils.getEmotionColor(emotionResult.emotion), //
                     ),
                   ),
                   Row(
                     children: [
                       Icon(Icons.check_circle_outline, color: EmotionUtils.getEmotionColor(emotionResult.emotion), size: 18), //
                       const SizedBox(width: 5),
                       Text(
                         '${(emotionResult.confidence * 100).toStringAsFixed(0)}% Confidence', //
                         style: TextStyle(
                           fontSize: 16,
                           color: EmotionUtils.getEmotionColor(emotionResult.emotion), //
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
             ],
           ),
           const SizedBox(height: 20),

           // Timings
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.timer, color: Colors.grey[600], size: 18), //
               const SizedBox(width: 5),
               Text( //
                 '${emotionResult.processingTimeMs}ms',
                 style: TextStyle(fontSize: 14, color: Colors.grey[600]), //
               ),
               const SizedBox(width: 15),
               Icon(Icons.memory, color: Colors.grey[600], size: 18), //
               const SizedBox(width: 5),
               Text( //
                 'EfficientNet-B0',
                 style: TextStyle(fontSize: 14, color: Colors.grey[600]), //
               ),
             ],
           ),
           const SizedBox(height: 30),

           // Action Buttons
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
             children: [
               // Details Button
               Expanded(
                 child: ElevatedButton.icon(
                   onPressed: () { //
                     _showDetailsDialog(context, emotionResult);
                     print('Details button pressed'); //
                   },
                   icon: const Icon(Icons.description, size: 20), //
                   label: const Text('Details'), //
                   style: ElevatedButton.styleFrom( //
                     backgroundColor: Colors.blue.shade50,
                     foregroundColor: Colors.blue.shade700,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(10),
                     ),
                     elevation: 0,
                   ),
                 ),
               ),
               const SizedBox(width: 15),

               // Save Button
               Expanded(
                 child: ElevatedButton.icon(
                   onPressed: () { //
                     print('Save button pressed'); //
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Save functionality not yet implemented.')),
                     );
                   },
                   icon: const Icon(Icons.save_alt, size: 20), //
                   label: const Text('Save'), //
                   style: ElevatedButton.styleFrom( //
                     backgroundColor: Colors.green.shade50,
                     foregroundColor: Colors.green.shade700,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(10),
                     ),
                     elevation: 0,
                   ),
                 ),
               ),
               const SizedBox(width: 15),

               // --- ADVISER BUTTON (Replaces Share Button) ---
               Expanded(
                 // Use Consumer to react to fetching state for this button only
                 child: Consumer<ImageDetectionProvider>(
                    builder: (context, consumerProvider, child) { // Renamed to avoid conflict
                      return ElevatedButton.icon(
                        // Disable button while advice is being fetched
                        onPressed: consumerProvider.isFetchingAdvice
                            ? null
                            : () {
                                // Explicitly tell provider to use *this* result's mood
                                // Assuming fetchAdvice uses provider's internal _currentResult,
                                // we should ensure it's set correctly or modify fetchAdvice.
                                // Simplest is to hope the provider's currentResult is correct,
                                // or add a method like:
                                // consumerProvider.fetchAdviceForMood(emotionResult.emotion);

                                // Using existing fetchAdvice for now:
                                consumerProvider.fetchAdvice();

                                // Show the advice dialog
                                _showAdviceDialog(context, consumerProvider);
                              },
                        // Show progress indicator or icon based on fetching state
                        icon: consumerProvider.isFetchingAdvice
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                              )
                            : const Icon(Icons.lightbulb_outline, size: 20), // Adviser icon
                        label: const Text('Adviser'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade50,
                          foregroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          // Dim the button slightly if disabled
                          disabledBackgroundColor: Colors.orange.shade50.withOpacity(0.5),
                        ),
                      );
                    }
                  ),
               ),
               // --- END ADVISER BUTTON ---
             ],
           ),
         ],
       ),
     );
  }

  void _showDetailsDialog(BuildContext context, EmotionResult result) {
    // Sort emotions by confidence (highest first) using original probabilities
    final sortedEmotions = result.allEmotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emotion Breakdown'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: sortedEmotions.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      )
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: entry.value, // Use the original probability from allEmotions
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          EmotionUtils.getEmotionColor(entry.key),
                        ),
                         minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${(entry.value * 100).toStringAsFixed(1)}%', // Display original probability
                         style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                         textAlign: TextAlign.right,
                      )
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  void _showAdviceDialog(BuildContext context, ImageDetectionProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // Use the emotionResult passed to this page for the title
          title: Text('${emotionResult.emotion} Adviser'),
          content: Consumer<ImageDetectionProvider>(
            builder: (ctx, p, child) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                   constraints: const BoxConstraints(minHeight: 100),
                   child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.isFetchingAdvice)
                          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                        else if (p.adviceText != null && p.adviceText!.isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Text(p.adviceText!, textAlign: TextAlign.center),
                           )
                        else if (p.error != null && p.adviceText != null) // Show error specifically if advice fetching failed
                            Text("Error getting advice: ${p.adviceText}", style: const TextStyle(color: Colors.red))
                        else
                          const Text('Tap the Adviser button again to get advice.'),
                        const SizedBox(height: 20),
                        _buildLanguageSelector(p),
                      ],
                   ),
                ),
              );
            },
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            Consumer<ImageDetectionProvider>(
              builder: (ctx, p, child) {
                bool canSpeak = p.adviceText != null && p.adviceText!.isNotEmpty && !p.isFetchingAdvice && !p.adviceText!.startsWith("Error");
                return IconButton(
                  icon: Icon(
                    p.isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    color: p.isSpeaking ? Colors.redAccent : Colors.deepPurple,
                  ),
                  iconSize: 30,
                  tooltip: p.isSpeaking ? 'Stop' : 'Read Aloud',
                  onPressed: canSpeak
                      ? (p.isSpeaking ? p.stopSpeaking : p.speakAdvice)
                      : null,
                );
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                provider.stopSpeaking();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
       provider.stopSpeaking();
       // Optionally clear advice text when dialog closes?
       // provider.clearAdvice();
    });
  }

  Widget _buildLanguageSelector(ImageDetectionProvider provider) {
    return DropdownButton<String>(
      value: provider.selectedLanguage,
      icon: const Icon(Icons.language, color: Colors.deepPurple, size: 20),
      dropdownColor: Colors.deepPurple.shade50,
      underline: Container(),
      isExpanded: true,
      onChanged: provider.isFetchingAdvice || provider.isSpeaking
          ? null
          : (String? newValue) {
              if (newValue != null && newValue != provider.selectedLanguage) {
                provider.setLanguage(newValue);
                // Refetch advice for the new language
                // Ensure provider uses the correct mood
                 provider.fetchAdvice(); // Assumes fetchAdvice uses provider's current mood state
              }
            },
      items: provider.availableLanguages
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Center(
            child: Text(
                value,
                style: const TextStyle(color: Colors.deepPurple, fontSize: 14),
            ),
          ),
        );
      }).toList(),
    );
  }
}