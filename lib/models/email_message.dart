class EmailMessage {
  final String id;
  final String sender;
  final String subject;
  final String snippet;
  final String body; // full plain-text body for LLM analysis
  final DateTime date;
  final List<Attachment> attachments;
  final bool hasPdfAttachment;

  EmailMessage({
    required this.id,
    required this.sender,
    required this.subject,
    required this.snippet,
    this.body = '',
    required this.date,
    this.attachments = const [],
    this.hasPdfAttachment = false,
  });
}

class Attachment {
  final String id;
  final String filename;
  final String mimeType;
  final int size;

  Attachment({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  bool get isPdf =>
      mimeType == 'application/pdf' ||
      (filename.toLowerCase().endsWith('.pdf') &&
          (mimeType == 'application/octet-stream' || mimeType.isEmpty));
}
