/// A review left on a user (`GET /users/:id/reviews`; reviewer is populated).
class Review {
  const Review({
    required this.id,
    required this.reviewerName,
    this.reviewerPhoto,
    required this.rating,
    this.comment,
  });

  final String id;
  final String reviewerName;
  final String? reviewerPhoto;
  final int rating;
  final String? comment;

  factory Review.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'];
    final name = reviewer is Map<String, dynamic>
        ? (reviewer['displayName'] ?? 'Someone') as String
        : 'Someone';
    final photo = reviewer is Map<String, dynamic>
        ? reviewer['photoUrl'] as String?
        : null;
    return Review(
      id: (json['_id'] ?? json['id']).toString(),
      reviewerName: name,
      reviewerPhoto: photo,
      rating: (json['rating'] ?? 0) as int,
      comment: json['comment'] as String?,
    );
  }
}

/// The signed-in user's own review of a specific swap (`GET /swaps/:id/review`,
/// `POST /swaps/:id/review`, `PATCH /reviews/:id`) — no reviewer info needed
/// since it's always the caller's own.
class MyReview {
  const MyReview({required this.id, required this.rating, this.comment});

  final String id;
  final int rating;
  final String? comment;

  factory MyReview.fromJson(Map<String, dynamic> json) {
    return MyReview(
      id: (json['_id'] ?? json['id']).toString(),
      rating: (json['rating'] ?? 0) as int,
      comment: json['comment'] as String?,
    );
  }
}
