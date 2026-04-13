import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rating_service.dart';

/// A reusable widget that shows a user's star rating summary.
class UserRatingBadge extends StatelessWidget {
  final double average;
  final int count;

  const UserRatingBadge({
    super.key,
    required this.average,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text(
        'No ratings yet',
        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
        const SizedBox(width: 4),
        Text(
          '${average.toStringAsFixed(1)}  ($count)',
          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Dialog to submit a star rating for another user.
class RatingDialog extends StatefulWidget {
  final String toUid;
  final String toUsername;

  const RatingDialog({super.key, required this.toUid, required this.toUsername});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedScore = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Rate ${widget.toUsername}',
        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How was your experience?',
            style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedScore = starValue),
                child: Icon(
                  _selectedScore >= starValue ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 38,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 2,
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Leave a comment (optional)',
              hintStyle: GoogleFonts.montserrat(fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_selectedScore == 0 || _isSubmitting)
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final success = await RatingService.submitRating(
                    toUid: widget.toUid,
                    toUsername: widget.toUsername,
                    score: _selectedScore,
                    comment: _commentController.text,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success
                        ? 'Rating submitted!'
                        : 'You have already rated ${widget.toUsername}.'),
                  ));
                },
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
