// File: lib/features/mood_detection/presentation/pages/image_mood_detection_page.dart
// *** CORRECTED FILE WITH ADVISER CHIP & ERROR FIXES ***

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/image_detection_provider.dart';
// Removed MoodResultsPage import
// import 'mood_results_page.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../data/models/emotion_result.dart';
import '../../../../core/utils/emotion_utils.dart';
// Import SharePlus if you still want the share logic available (even if button removed)
import 'package:share_plus/share_plus.dart';

class ImageMoodDetectionPage extends StatefulWidget {
  const ImageMoodDetectionPage({super.key}); //

  @override
  State<ImageMoodDetectionPage> createState() => _ImageMoodDetectionPageState();
}

class _ImageMoodDetectionPageState extends State<ImageMoodDetectionPage>
    with SingleTickerProviderStateMixin { //
  final ImagePicker _picker = ImagePicker(); //
  File? _selectedImage; //
  bool _isProcessing = false; //
  EmotionResult? _currentEmotionResult; // State to hold the result

  late AnimationController _resultCardAnimationController; //
  late Animation<double> _resultCardScaleAnimation; //

  @override
  void initState() {
    super.initState();
    _resultCardAnimationController = AnimationController( //
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultCardScaleAnimation = CurvedAnimation( //
      parent: _resultCardAnimationController,
      curve: Curves.easeOutBack,
    );

     WidgetsBinding.instance.addPostFrameCallback((_) {
       Provider.of<ImageDetectionProvider>(context, listen: false).initialize();
     });
  }

  @override
  void dispose() {
    _resultCardAnimationController.dispose(); //
    super.dispose();
  }


  Future<void> _pickImage(ImageSource source) async { //
    setState(() {
      _selectedImage = null;
      _currentEmotionResult = null;
      _isProcessing = false;
      _resultCardAnimationController.reset();
    });

    try {
      final XFile? pickedFile = await _picker.pickImage( //
          source: source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path); //
        setState(() {
          _selectedImage = imageFile;
        });
         await _processImage(imageFile); //
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e'); // Use Snackbar for errors
    }
  }

  Future<void> _processImage(File imageFile) async { //
    final provider = Provider.of<ImageDetectionProvider>(context, listen: false); //

    if (!provider.isInitialized) { //
      _showErrorSnackbar('Emotion recognizer not ready. Please wait or restart the app.');
      return;
    }

    // Reset advice state in provider before processing new image
    provider.resetAdviceStateOnly(); // Ensure this method exists in provider

    setState(() {
       _isProcessing = true; //
       _currentEmotionResult = null;
       _resultCardAnimationController.reset();
    });

    try {
      // Use the provider's processImage method which also updates its internal _currentResult
      final result = await provider.processImage(imageFile); //

      setState(() {
        _currentEmotionResult = result; // Store result to display locally
         _isProcessing = false; //
      });
      // Animate card in, even if it's an error card
      _resultCardAnimationController.forward();

      // --- NO NAVIGATION HERE ---

    } catch (e) {
      final errorMessage = 'Error processing image: $e';
      setState(() {
         _isProcessing = false; //
         // Store error result to display in the result area
         _currentEmotionResult = EmotionResult.error(errorMessage); //
      });
       _showErrorSnackbar(errorMessage);
    }
  }

   // Changed to Snackbar for less intrusive error display
   void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar( //
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Share function - kept for reference
  Future<void> _shareResult(EmotionResult result) async { //
    if (_selectedImage == null) return;
    try {
      final text = 'I\'m feeling ${result.emotion}! Mood detected with ${(result.confidence * 100).toStringAsFixed(1)}% confidence via MindHeal.'; //
      await Share.shareXFiles([XFile(_selectedImage!.path)], text: text); //
    } catch (e) {
      _showErrorSnackbar('Error sharing result: $e'); //
    }
  }

  // --- Placeholder Save function ---
  void _saveResult(EmotionResult result) { //
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Save functionality not implemented yet.')),
     );
     // Add logic here to save the result (e.g., using MoodDatabaseService)
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detect Mood from Image'),
      ),
      body: Center(
        child: Column( // Use Column to layout elements
            mainAxisAlignment: MainAxisAlignment.start, // Align top
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // --- Image Preview Area ---
              Expanded( // Allow image preview/placeholder to take available space
                flex: 5, // Give more space to image/result
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isProcessing
                      // ***** FIX 1: Removed 'text' parameter *****
                      ? const LoadingIndicator() // Use without 'text'
                      : _selectedImage != null
                          ? ClipRRect( //
                              borderRadius: BorderRadius.circular(15.0),
                              child: Image.file( //
                                _selectedImage!,
                                fit: BoxFit.contain, // Use contain to see whole image
                              ),
                            )
                          : Column( // Placeholder when no image selected
                              mainAxisAlignment: MainAxisAlignment.center, //
                              children: [
                                Icon(Icons.image_search_outlined, size: 100, color: Colors.grey.shade400), //
                                const SizedBox(height: 10),
                                Text(
                                  'Select an image using the buttons below',
                                  style: TextStyle(color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                )
                              ],
                            ),
                ),
              ),
              const Divider(), // Separator

              // --- Result Display Area (Animated) ---
              Expanded( // Let result card take space too
                flex: 4, // Adjust flex as needed
                child: SingleChildScrollView( // Allow result card to scroll if content overflows
                   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                   child: _currentEmotionResult != null && !_isProcessing
                       ? ScaleTransition( //
                          scale: _resultCardScaleAnimation, //
                          child: _buildResultDisplay(context, _currentEmotionResult!), // Display result or error
                        )
                       // Show nothing or a placeholder while no result
                       : const SizedBox(height: 100), // Reserve some space
                 ),
              ),


             // --- Action Buttons (Pick Image) ---
              Padding( // Keep padding for buttons
                padding: const EdgeInsets.only(bottom: 30.0, top: 10.0, left: 16.0, right: 16.0),
                child: Row( //
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, //
                    children: [
                      _buildActionButton( //
                        icon: Icons.photo_library, //
                        label: 'Gallery', //
                        color: Colors.green, //
                        // Disable buttons while processing
                        onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery), //
                      ),
                      _buildActionButton( //
                        icon: Icons.camera_alt, //
                        label: 'Camera', //
                        color: Colors.blue, //
                        // Disable buttons while processing
                        onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera), //
                      ),
                    ],
                  ),
              ),
            ],
          ),
      ),
    );
  }


  // =============================================== //
  // === RESULT DISPLAY WIDGET (Builds the card) === //
  // =============================================== //
  Widget _buildResultDisplay(BuildContext context, EmotionResult result) { //
    // Access provider for advice state
    final provider = Provider.of<ImageDetectionProvider>(context, listen: false);

    // --- FIX 2: Handle error state display ---
    if (result.hasError) { //
       return Card(
          elevation: 4.0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                     // FIX: Use the 'emotion' field which holds the error message
                     result.emotion, //
                     style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
       );
    }
    // --- End Error Handling ---


    // --- Normal Result Display ---

    // Determine accuracy/confidence level text and color
    String confidenceLevel; //
    Color accuracyColor; //
    if (result.confidence >= 0.85) { //
      confidenceLevel = 'High Accuracy'; //
      accuracyColor = Colors.green.shade700; //
    } else if (result.confidence >= 0.6) { //
      confidenceLevel = 'Moderate Accuracy'; //
      accuracyColor = Colors.orange.shade700; //
    } else {
      confidenceLevel = 'Low Accuracy'; //
      accuracyColor = Colors.red.shade700; //
    }

     // Find second best emotion if needed
     Map<String, dynamic>? secondBestEmotion; //
     if (result.allEmotions.isNotEmpty && result.confidence < 0.85) { //
       final sortedEmotions = result.allEmotions.entries.toList() //
         ..sort((a, b) => b.value.compareTo(a.value));
       if (sortedEmotions.length > 1 && sortedEmotions[1].value > 0.1) { //
         secondBestEmotion = { //
           'emotion': sortedEmotions[1].key,
           'confidence': sortedEmotions[1].value,
         };
       }
     }

    return Card( //
      elevation: 4.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)), //
      child: Padding(
        padding: const EdgeInsets.all(16.0), //
        child: Column(
          mainAxisSize: MainAxisSize.min, //
          children: [
            // --- Top Section: Icon, Emotion, Confidence ---
            Row( //
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon( //
                  EmotionUtils.getEmotionIcon(result.emotion), //
                  size: 40,
                  color: EmotionUtils.getEmotionColor(result.emotion), //
                ),
                const SizedBox(width: 16),
                Column( //
                  crossAxisAlignment: CrossAxisAlignment.start, //
                  children: [
                    Text( //
                      result.emotion.toUpperCase(),
                      style: TextStyle( //
                        fontSize: 24,
                        fontWeight: FontWeight.bold, //
                        color: EmotionUtils.getEmotionColor(result.emotion), //
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row( //
                      children: [
                        Icon(Icons.check_circle_outline, color: accuracyColor, size: 16), //
                        const SizedBox(width: 4),
                        Text( //
                          '${(result.confidence * 100).toStringAsFixed(0)}% Confidence', //
                          style: TextStyle( //
                            fontSize: 14,
                            color: accuracyColor,
                            fontWeight: FontWeight.w600, //
                          ),
                        ),
                      ],
                    ),
                     const SizedBox(height: 4), //
                    Text( //
                      confidenceLevel,
                      style: TextStyle( //
                        fontSize: 12,
                        color: accuracyColor,
                        fontWeight: FontWeight.w500, //
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12), //

            // --- Middle Section: Performance Metrics ---
             Container( //
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), //
               decoration: BoxDecoration( //
                 color: Colors.grey[100], //
                 borderRadius: BorderRadius.circular(20), //
               ),
               child: Row( //
                 mainAxisSize: MainAxisSize.min, //
                 children: [
                   Icon(Icons.speed, size: 14, color: Colors.grey[600]), //
                   const SizedBox(width: 4), //
                   Text( //
                     '${result.processingTimeMs}ms',
                     style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500), //
                   ),
                   const SizedBox(width: 12), //
                   Icon(Icons.model_training, size: 14, color: Colors.grey[600]), //
                   const SizedBox(width: 4), //
                   Text( //
                     'EfficientNet-B0',
                     style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500), //
                   ),
                 ],
               ),
             ),

            // --- Alternative Emotion (Conditional) ---
            if (result.confidence < 0.85 && secondBestEmotion != null) ...[ //
              const SizedBox(height: 12), //
              Container( //
                padding: const EdgeInsets.all(8), //
                decoration: BoxDecoration( //
                  color: Colors.orange[50], //
                  borderRadius: BorderRadius.circular(8), //
                  border: Border.all(color: Colors.orange[200]!), //
                ),
                child: Row( //
                  mainAxisSize: MainAxisSize.min, //
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange[600]), //
                    const SizedBox(width: 6), //
                    Text( //
                      'Alternative: ${secondBestEmotion['emotion']} (${(secondBestEmotion['confidence'] * 100).toInt()}%)', //
                      style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500), //
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16), //

            // ======================================== //
            // === ACTION CHIPS ROW (Wrap) - UPDATED === //
            // ======================================== //
            Wrap( //
              spacing: 10, // Horizontal spacing //
              runSpacing: 8, // Vertical spacing if they wrap
              alignment: WrapAlignment.center, // Center the chips
              children: [
                // --- Details Chip ---
                _buildActionChip( //
                  icon: Icons.analytics_outlined, //
                  label: 'Details', //
                  color: Colors.blue, //
                  onTap: () => _showDetailsDialog(context, result), //
                ),
                // --- Save Chip ---
                _buildActionChip( //
                  icon: Icons.save_outlined, //
                  label: 'Save', //
                  color: Colors.green, //
                  onTap: () => _saveResult(result), //
                ),

                // --- FIX 3: ADVISER CHIP (Replaces Share Chip) ---
                 Consumer<ImageDetectionProvider>( // Consumer for loading state
                   builder: (context, consumerProvider, child) {
                     return _buildActionChip(
                        icon: consumerProvider.isFetchingAdvice
                            ? Icons.hourglass_top // Use a spinner or hourglass
                            : Icons.lightbulb_outline, // Adviser Icon
                        label: consumerProvider.isFetchingAdvice
                            ? 'Loading...' // Indicate loading
                            : 'Adviser',
                        color: Colors.orange, // Keep orange color like Share
                        // Disable tap while fetching, otherwise fetch advice
                        onTap: consumerProvider.isFetchingAdvice
                            ? (){} // Do nothing if already fetching
                            : () { // Fetch advice on tap
                                // Use the method that takes the mood directly
                                consumerProvider.fetchAdviceForMood(result.emotion);
                                _showAdviceDialog(context, consumerProvider, result.emotion);
                              },
                      );
                   }
                 ),
                 // --- END ADVISER CHIP ---

                 // --- Original Share Chip (REMOVED) ---
                 /*
                 _buildActionChip( //
                   icon: Icons.share_outlined, //
                   label: 'Share', //
                   color: Colors.orange, //
                   onTap: () => _shareResult(result), //
                 ),
                 */
                 // --- End Original Share Chip ---
              ],
            ),
            // --- End Action Chips Row ---
          ],
        ),
      ),
    );
  }

  // --- Builds individual action chip ---
  Widget _buildActionChip({ //
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Check if the label indicates loading state for visual feedback
    bool isLoading = label == 'Loading...';

    return GestureDetector( //
      onTap: isLoading ? null : onTap, // Disable tap if loading
      child: Container( //
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), //
        decoration: BoxDecoration( //
          color: color.withOpacity(0.1), //
          borderRadius: BorderRadius.circular(16), //
          border: Border.all(color: color.withOpacity(0.3)), //
        ),
        child: Row( //
          mainAxisSize: MainAxisSize.min, //
          children: [
            // Show progress indicator instead of icon if loading
            isLoading
              ? SizedBox(
                  width: 16, //
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 16), //
            const SizedBox(width: 6), //
            Text( //
              label,
              style: TextStyle( //
                color: color,
                fontWeight: FontWeight.w600, //
                fontSize: 12, //
              ),
            ),
          ],
        ),
      ),
    );
  }


  // --- Action Button for Picking Image (FAB style) ---
   Widget _buildActionButton({ //
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container( //
      decoration: BoxDecoration( //
        borderRadius: BorderRadius.circular(25), //
        boxShadow: onPressed != null //
            ? [ BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)) ] //
            : null,
      ),
      child: FloatingActionButton.extended( //
        heroTag: label.toLowerCase(), //
        onPressed: onPressed, //
        backgroundColor: onPressed != null ? color : Colors.grey.shade400, //
        foregroundColor: Colors.white, //
        elevation: onPressed != null ? 2 : 0, //
        icon: Icon(icon, size: 24), //
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), //
      ),
    );
  }

   // --- Shows the breakdown of all emotion probabilities ---
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
                    SizedBox(width: 80, child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: entry.value, // Use the original probability from allEmotions
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(EmotionUtils.getEmotionColor(entry.key)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 45, child: Text('${(entry.value * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.right)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')) ],
      ),
    );
  }

  // --- Shows the Gemini advice, language selector, and TTS controls ---
  void _showAdviceDialog(BuildContext context, ImageDetectionProvider provider, String emotionForTitle) { // Added emotionForTitle
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // Use the emotion passed for the title
          title: Text('$emotionForTitle Adviser'),
          // Use Consumer for content that needs to rebuild
          content: Consumer<ImageDetectionProvider>(
            builder: (ctx, p, child) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                   constraints: const BoxConstraints(minHeight: 100), // Min height
                   child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show loading indicator WHILE fetching
                        if (p.isFetchingAdvice)
                          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                        // Show advice text AFTER fetching is done and text is available
                        else if (p.adviceText != null && p.adviceText!.isNotEmpty && !p.adviceText!.startsWith("Error"))
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Text(p.adviceText!, textAlign: TextAlign.center),
                           )
                        // Show error message if fetching failed (check adviceText content)
                        else if (p.adviceText != null && p.adviceText!.startsWith("Error"))
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Text(p.adviceText!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
                           )
                        // Initial state or unexpected failure
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Could not fetch advice. Please try again or select a language.', textAlign: TextAlign.center),
                          ),
                        const SizedBox(height: 20),
                        // Always show language selector
                        _buildLanguageSelector(p, emotionForTitle), // Pass emotion for refetch
                      ],
                   ),
                ),
              );
            },
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween, // Align buttons nicely
          actions: <Widget>[
            // --- Read Aloud / Stop Button ---
            Consumer<ImageDetectionProvider>(
              builder: (ctx, p, child) {
                // Enable only if there's valid advice text and not fetching
                bool canSpeak = p.adviceText != null && p.adviceText!.isNotEmpty && !p.adviceText!.startsWith("Error") && !p.isFetchingAdvice;
                return IconButton(
                  icon: Icon(
                    p.isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    color: p.isSpeaking ? Colors.redAccent : Colors.deepPurple,
                  ),
                  iconSize: 30,
                  tooltip: p.isSpeaking ? 'Stop' : 'Read Aloud',
                  onPressed: canSpeak
                      ? (p.isSpeaking ? p.stopSpeaking : p.speakAdvice)
                      : null, // Disable if cannot speak
                );
              },
            ),
            // --- Close Button ---
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                provider.stopSpeaking(); // Stop TTS before closing
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
       // Ensure TTS stops if dialog is dismissed by other means (e.g., back button)
       provider.stopSpeaking();
    });
  }

  // --- Builds the language dropdown ---
  Widget _buildLanguageSelector(ImageDetectionProvider provider, String currentMood) { // Added currentMood
    return DropdownButton<String>(
      value: provider.selectedLanguage,
      icon: const Icon(Icons.language, color: Colors.deepPurple, size: 20),
      dropdownColor: Colors.deepPurple.shade50,
      underline: Container(), // Removes underline
      isExpanded: true, // Makes dropdown take available width
      // Disable dropdown while fetching or speaking
      onChanged: provider.isFetchingAdvice || provider.isSpeaking
          ? null
          : (String? newValue) {
              if (newValue != null && newValue != provider.selectedLanguage) {
                provider.setLanguage(newValue);
                // Automatically refetch advice for the new language FOR THIS MOOD
                 provider.fetchAdviceForMood(currentMood); // Use the passed mood
              }
            },
      items: provider.availableLanguages
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Center( // Center text within dropdown
            child: Text(
                value,
                style: const TextStyle(color: Colors.deepPurple, fontSize: 14),
            ),
          ),
        );
      }).toList(),
    );
  }

} // End of _ImageMoodDetectionPageState