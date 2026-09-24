import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/businesses/data/business_dto.dart';
import 'package:ranco_conecta_2/features/categories/data/category_dto.dart';
import 'package:ranco_conecta_2/features/messaging/data/messaging_repository.dart';
import 'package:ranco_conecta_2/features/notifications/data/notification_repository.dart';
import 'package:ranco_conecta_2/features/profile/data/profile_dto.dart';
import 'package:ranco_conecta_2/features/service_requests/data/quote_repository.dart';
import 'package:ranco_conecta_2/features/service_requests/data/request_attachment_repository.dart';
import 'package:ranco_conecta_2/features/service_requests/data/service_request_dto.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/conversation.dart';
import 'package:ranco_conecta_2/shared/models/quote.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';
import 'package:ranco_conecta_2/shared/models/service_request_status.dart';

void main() {
  test('maps category dto to domain', () {
    final category = CategoryDto.fromJson({
      'id': 'cat-1',
      'name': 'Hogar',
      'slug': 'home',
      'icon_key': 'tools',
      'theme_key': 'forest',
    }).toDomain();

    expect(category.slug, 'home');
    expect(category.iconKey, 'tools');
  });

  test('maps profile role without exposing raw strings to UI', () {
    final profile = ProfileDto.fromJson({
      'id': 'user-1',
      'full_name': 'Bruno',
      'phone': null,
      'avatar_url': null,
      'role': 'super_admin',
      'account_status': 'active',
    }).toDomain();

    expect(profile.role, ProfileRole.superAdmin);
    expect(profile.role.label, 'Super admin');
  });

  test('maps business with nested services and coverage', () {
    final business = BusinessDto.fromJson({
      'id': 'biz-1',
      'owner_id': 'user-1',
      'business_type': 'service',
      'name': 'Servicios Ranco',
      'slug': 'servicios-ranco',
      'description': 'Mantención local',
      'phone': '+56912345678',
      'whatsapp': '+56912345678',
      'email': null,
      'website': null,
      'verification_status': 'verified',
      'business_services': [
        {
          'description': null,
          'price_from': 10000,
          'subcategory_id': 'sub-1',
          'subcategories': {
            'id': 'sub-1',
            'category_id': 'cat-1',
            'name': 'Gasfitería',
            'slug': 'plumbing',
            'description': null,
            'icon_key': 'plumbing',
          },
        },
      ],
      'business_coverage': [
        {
          'location_id': 'loc-1',
          'locations': {
            'id': 'loc-1',
            'commune_id': 'com-1',
            'name': 'Lago Ranco',
            'slug': 'lago-ranco',
          },
        },
      ],
      'business_hours': [],
      'business_media': [],
    }).toDomain();

    expect(business.type, BusinessType.service);
    expect(business.isVerified, isTrue);
    expect(business.services.single.subcategory.name, 'Gasfitería');
    expect(business.coverage.single.name, 'Lago Ranco');
  });

  test('maps service request dto with database status values', () {
    final request = ServiceRequestDto.fromJson({
      'id': 'request-1',
      'public_code': 'RC-2026-000001',
      'business_id': 'business-1',
      'category_id': 'category-1',
      'subcategory_id': 'subcategory-1',
      'location_id': 'location-1',
      'description': 'Necesito mantencion de calefont.',
      'address_text': 'Lago Ranco',
      'urgency': 'high',
      'desired_date': '2026-09-24',
      'status': 'quoted',
      'created_at': '2026-09-23T12:00:00Z',
      'businesses': {'name': 'Servicios Ranco'},
      'categories': {'name': 'Hogar'},
      'subcategories': {'name': 'Gasfiteria'},
      'locations': {'name': 'Lago Ranco'},
    }).toDomain();

    expect(request.status, ServiceRequestStatus.quoted);
    expect(request.categoryName, 'Hogar');
    expect(request.locationId, 'location-1');
    expect(request.locationName, 'Lago Ranco');
    expect(request.businessName, 'Servicios Ranco');
    expect(request.subcategoryName, 'Gasfiteria');
  });

  test('maps quote dto without using floating point money', () {
    final quote = QuoteDto.fromJson({
      'id': 'quote-1',
      'request_id': 'request-1',
      'business_id': 'business-1',
      'total_amount': 125000,
      'description': 'Incluye visita y materiales.',
      'expires_at': '2026-09-30T12:00:00Z',
      'status': 'pending',
      'created_at': '2026-09-23T12:00:00Z',
      'businesses': {'name': 'Servicios Ranco'},
    });

    expect(quote.status, QuoteStatus.pending);
    expect(quote.totalAmount, 125000);
    expect(quote.formattedTotal, r'$125.000');
  });

  test('maps request attachment metadata', () {
    final attachment = RequestAttachmentRepository.fromJsonForTest({
      'id': 'attachment-1',
      'request_id': 'request-1',
      'storage_path': 'requests/request-1/file.jpg',
      'file_name': 'foto.jpg',
      'mime_type': 'image/jpeg',
      'size_bytes': 2048,
      'created_at': '2026-09-23T12:00:00Z',
    });

    expect(attachment.isImage, isTrue);
    expect(attachment.isPdf, isFalse);
    expect(attachment.fileName, 'foto.jpg');
  });

  test('maps conversation summary with unread state', () {
    final summary = ConversationSummaryDto.fromJson({
      'id': 'conversation-1',
      'context_type': 'service_request',
      'context_id': 'request-1',
      'request_id': 'request-1',
      'title': 'Servicios Ranco',
      'preview': 'Vamos en camino',
      'last_message_at': '2026-09-23T12:00:00Z',
      'unread_count': 2,
    });

    expect(summary, isA<ConversationSummary>());
    expect(summary.contextType, 'service_request');
    expect(summary.unreadCount, 2);
  });

  test('maps conversation message and ownership flag', () {
    final message = ChatMessageDto.fromJson({
      'id': 'message-1',
      'conversation_id': 'conversation-1',
      'sender_id': 'user-1',
      'sender_name': 'Bruno',
      'message_type': 'text',
      'body': 'Hola',
      'attachment_path': null,
      'created_at': '2026-09-23T12:00:00Z',
      'is_mine': true,
    });

    expect(message.body, 'Hola');
    expect(message.isMine, isTrue);
  });

  test('maps notification with deep link read state', () {
    final notification = AppNotificationDto.fromJson({
      'id': 'notification-1',
      'type': 'new_message',
      'title': 'Nuevo mensaje',
      'body': 'Tienes un nuevo mensaje.',
      'entity_type': 'conversation',
      'entity_id': 'conversation-1',
      'deep_link': '/messages/conversation-1',
      'read_at': null,
      'created_at': '2026-09-23T12:00:00Z',
    });

    expect(notification.isUnread, isTrue);
    expect(notification.deepLink, '/messages/conversation-1');
  });
}
