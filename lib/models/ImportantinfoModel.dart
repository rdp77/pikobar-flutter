import 'package:cloud_firestore/cloud_firestore.dart';

class ImportantinfoModel {
  String id;
  String title;
  String content;
  String image;
  String actionUrl;
  String actionTitle;
  String attachmentUrl;
  bool published;
  int publishedAt;

  ImportantinfoModel({
    this.id,
    this.title,
    this.content,
    this.image,
    this.actionUrl,
    this.actionTitle,
    this.attachmentUrl,
    this.published,
    this.publishedAt,
  });

  factory ImportantinfoModel.fromFirestore(DocumentSnapshot document) {
    Map<String, dynamic> json = document.data;

    return ImportantinfoModel(
      id: document.documentID,
      title: json["title"] ?? '',
      content: json["content"] ?? '',
      image: json["image"] ?? '',
      actionUrl: json["action_url"] ?? '',
      actionTitle: json["action_title"] ?? '',
      attachmentUrl: json["attachment_url"] ?? '',
      published: json["published"] ?? false,
      publishedAt:
          json["published_at"] != null ? json["published_at"].seconds : null,
    );
  }
}
