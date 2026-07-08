import { Types } from 'mongoose';
import { Conversation, ConversationDoc, pairKeyFor } from '../models/conversation.model';
import { Message, MessageDoc, MessageType } from '../models/message.model';
import { User } from '../models/user.model';
import { tierLimits } from '../config/limits';
import { ANTI_SPAM } from '../config/limits';
import { emitToRoom, notificationService } from './notification.service';
import { safetyService } from './safety.service';
import { Errors } from '../utils/errors';

function convRoom(conversationId: string): string {
  return `conv:${conversationId}`;
}

async function assertParticipant(conversationId: string, userId: string): Promise<ConversationDoc> {
  const conv = await Conversation.findById(conversationId);
  if (!conv) throw Errors.notFound('Conversation not found');
  if (!conv.participants.some((p) => String(p) === userId)) {
    throw Errors.forbidden('Not a participant of this conversation');
  }
  return conv;
}

export const messagingService = {
  /** Find-or-create the conversation for a pair of users. */
  async getOrCreateConversation(aId: string, bId: string): Promise<ConversationDoc> {
    if (aId === bId) throw Errors.badRequest('Cannot message yourself');

    const pairKey = pairKeyFor(aId, bId);
    const existing = await Conversation.findOne({ pairKey });
    if (existing) return existing;

    const blocked = await safetyService.blockedUserIds(aId);
    if (blocked.some((id) => String(id) === bId)) {
      throw Errors.forbidden('You can’t message this user', 'BLOCKED');
    }

    try {
      return await Conversation.create({
        participants: [new Types.ObjectId(aId), new Types.ObjectId(bId)],
        pairKey,
      });
    } catch (err) {
      if ((err as { code?: number }).code === 11000) {
        return (await Conversation.findOne({ pairKey }))!;
      }
      throw err;
    }
  },

  async listConversations(userId: string) {
    const convs = await Conversation.find({ participants: userId })
      .sort({ lastMessageAt: -1, updatedAt: -1 })
      .populate('participants', 'displayName photoUrl ratingAvg');

    return Promise.all(
      convs.map(async (c) => {
        const unreadCount = await Message.countDocuments({
          conversation: c._id,
          sender: { $ne: new Types.ObjectId(userId) },
          readBy: { $ne: new Types.ObjectId(userId) },
        });
        return { ...c.toJSON(), unreadCount };
      }),
    );
  },

  async getConversation(id: string, userId: string): Promise<ConversationDoc> {
    return assertParticipant(id, userId);
  },

  async listMessages(
    conversationId: string,
    userId: string,
    opts: { cursor?: string; limit: number },
  ): Promise<{ items: MessageDoc[]; nextCursor: string | null }> {
    await assertParticipant(conversationId, userId);
    const filter: Record<string, unknown> = { conversation: conversationId };
    if (opts.cursor) filter._id = { $lt: new Types.ObjectId(opts.cursor) };
    const docs = await Message.find(filter)
      .sort({ _id: -1 })
      .limit(opts.limit + 1);
    const hasMore = docs.length > opts.limit;
    const items = hasMore ? docs.slice(0, opts.limit) : docs;
    return { items, nextCursor: hasMore ? String(items[items.length - 1]._id) : null };
  },

  async getMessage(messageId: string, userId: string): Promise<MessageDoc> {
    const msg = await Message.findById(messageId);
    if (!msg) throw Errors.notFound('Message not found');
    await assertParticipant(String(msg.conversation), userId);
    return msg;
  },

  /** Send a message. Text is free; multimedia requires Premium (FR-008). */
  async sendMessage(
    conversationId: string,
    senderId: string,
    input: { type?: MessageType; body?: string; mediaUrl?: string },
  ): Promise<MessageDoc> {
    const conv = await assertParticipant(conversationId, senderId);
    const type = input.type ?? 'text';

    if (type !== 'text') {
      const user = await User.findById(senderId).select('tier');
      if (!user || !tierLimits(user.tier).multimediaMessaging) {
        throw Errors.premiumRequired('Multimedia messaging requires Premium');
      }
      if (!input.mediaUrl) throw Errors.badRequest('mediaUrl is required for non-text messages');
    } else if (!input.body || !input.body.trim()) {
      throw Errors.badRequest('Message body is required');
    }

    const msg = await Message.create({
      conversation: conversationId,
      sender: senderId,
      type,
      body: input.body,
      mediaUrl: input.mediaUrl,
      readBy: [new Types.ObjectId(senderId)],
    });

    const preview = type === 'text' ? (input.body ?? '') : `[${type}]`;
    conv.lastMessageAt = new Date();
    conv.lastMessagePreview = preview.slice(0, 140);
    await conv.save();

    emitToRoom(convRoom(conversationId), 'message:new', { message: msg.toJSON() });

    // Notify the other participant(s) (socket when online, FCM fallback when offline).
    // Title is the sender's name (not a generic "New message") so both the
    // OS notification and in-app popup read like a real chat app; photoUrl
    // rides along so the client can show it as the notification's avatar.
    const sender = await User.findById(senderId).select('displayName photoUrl');
    const recipients = conv.participants.map(String).filter((id) => id !== senderId);
    await Promise.all(
      recipients.map((userId) =>
        notificationService.notify({
          userId,
          type: 'message_received',
          title: sender?.displayName || 'New message',
          body: preview.slice(0, 120),
          data: {
            conversationId,
            senderId,
            messageId: String(msg._id),
            senderName: sender?.displayName ?? '',
            senderPhotoUrl: sender?.photoUrl ?? '',
          },
        }),
      ),
    );
    return msg;
  },

  /** Edit own text message within the edit window (FR-037). */
  async editMessage(messageId: string, userId: string, body: string): Promise<MessageDoc> {
    const msg = await Message.findById(messageId);
    if (!msg) throw Errors.notFound('Message not found');
    if (String(msg.sender) !== userId) throw Errors.forbidden('You can only edit your own messages');
    if (msg.type !== 'text') throw Errors.badRequest('Only text messages can be edited');
    if (msg.deletedAt) throw Errors.badRequest('Message was deleted');

    const ageMs = Date.now() - msg.createdAt.getTime();
    if (ageMs > ANTI_SPAM.messageEditWindowMinutes * 60 * 1000) {
      throw Errors.badRequest('Edit window has expired', { code: 'EDIT_WINDOW_EXPIRED' });
    }

    msg.body = body;
    msg.editedAt = new Date();
    await msg.save();
    emitToRoom(convRoom(String(msg.conversation)), 'message:updated', {
      messageId: String(msg._id),
      body: msg.body,
      editedAt: msg.editedAt,
    });
    return msg;
  },

  async deleteMessage(messageId: string, userId: string): Promise<void> {
    const msg = await Message.findById(messageId);
    if (!msg) throw Errors.notFound('Message not found');
    if (String(msg.sender) !== userId) throw Errors.forbidden('You can only delete your own messages');
    msg.deletedAt = new Date();
    msg.body = undefined;
    msg.mediaUrl = undefined;
    await msg.save();
    emitToRoom(convRoom(String(msg.conversation)), 'message:deleted', { messageId: String(msg._id) });
  },

  /** Mark messages up to `lastReadMessageId` as read by the user. */
  async markRead(conversationId: string, userId: string, lastReadMessageId: string): Promise<void> {
    await assertParticipant(conversationId, userId);
    await Message.updateMany(
      {
        conversation: conversationId,
        _id: { $lte: new Types.ObjectId(lastReadMessageId) },
        readBy: { $ne: new Types.ObjectId(userId) },
      },
      { $addToSet: { readBy: new Types.ObjectId(userId) } },
    );
    emitToRoom(convRoom(conversationId), 'message:read', { conversationId, userId, lastReadMessageId });
  },
};
