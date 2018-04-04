//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSQuotedMessageView.h"
#import "ConversationViewItem.h"
#import "Environment.h"
#import "OWSMessageCell.h"
#import "Signal-Swift.h"
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/SignalMessaging-Swift.h>
#import <SignalMessaging/UIColor+OWS.h>
#import <SignalMessaging/UIView+OWS.h>
#import <SignalServiceKit/TSAttachmentStream.h>
#import <SignalServiceKit/TSMessage.h>
#import <SignalServiceKit/TSQuotedMessage.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSQuotedMessageView ()

@property (nonatomic, readonly) TSQuotedMessage *quotedMessage;
@property (nonatomic, nullable, readonly) DisplayableText *displayableQuotedText;

@property (nonatomic, readonly) UIFont *textMessageFont;

@property (nonatomic, readonly) UIColor *strokeColor;
@property (nonatomic, readonly) CGFloat strokeThickness;

// TODO: Replace with a bubble stroke view.
@property (nonatomic) CAShapeLayer *shapeLayer;

@property (nonatomic, weak) OWSBubbleView *bubbleView;

@end

@implementation OWSQuotedMessageView

+ (OWSQuotedMessageView *)quotedMessageViewForConversation:(TSQuotedMessage *)quotedMessage
                                     displayableQuotedText:(nullable DisplayableText *)displayableQuotedText
{
    OWSAssert(quotedMessage);

    return
        [[OWSQuotedMessageView alloc] initWithQuotedMessage:quotedMessage displayableQuotedText:displayableQuotedText];
}

+ (OWSQuotedMessageView *)quotedMessageViewForPreview:(TSQuotedMessage *)quotedMessage
{
    OWSAssert(quotedMessage);

    DisplayableText *_Nullable displayableQuotedText = nil;
    if (quotedMessage.body.length > 0) {
        displayableQuotedText = [DisplayableText displayableText:quotedMessage.body];
    }

    return
        [[OWSQuotedMessageView alloc] initWithQuotedMessage:quotedMessage displayableQuotedText:displayableQuotedText];
}

- (instancetype)initWithQuotedMessage:(TSQuotedMessage *)quotedMessage
                displayableQuotedText:(nullable DisplayableText *)displayableQuotedText
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSAssert(quotedMessage);
    OWSAssert(displayableQuotedText);

    _quotedMessage = quotedMessage;
    _displayableQuotedText = displayableQuotedText;
    _textMessageFont = OWSMessageCell.defaultTextMessageFont;
    _strokeColor = OWSMessagesBubbleImageFactory.bubbleColorIncoming;
    _strokeThickness = 1.f;

    self.shapeLayer = [CAShapeLayer new];
    [self.layer addSublayer:self.shapeLayer];

    return self;
}

- (BOOL)hasQuotedAttachmentThumbnail
{
    return (self.quotedMessage.contentType.length > 0 &&
        [TSAttachmentStream hasThumbnailForMimeType:self.quotedMessage.contentType]);
}

#pragma mark -

- (void)createContents
{
    self.backgroundColor = [UIColor whiteColor];
    self.userInteractionEnabled = NO;
    self.layoutMargins = UIEdgeInsetsZero;
    self.clipsToBounds = YES;

    UIView *_Nullable quotedAttachmentView = nil;
    // TODO:
    //    if (self.hasQuotedAttachmentThumbnail)
    {
        // TODO:
        quotedAttachmentView = [UIView containerView];
        quotedAttachmentView.userInteractionEnabled = NO;
        quotedAttachmentView.backgroundColor = [UIColor redColor];
        [self addSubview:quotedAttachmentView];
        [quotedAttachmentView autoPinTrailingToSuperviewMarginWithInset:self.quotedContentHInset];
        [quotedAttachmentView autoVCenterInSuperview];
        [quotedAttachmentView autoSetDimension:ALDimensionWidth toSize:self.quotedAttachmentSize];
        [quotedAttachmentView autoSetDimension:ALDimensionHeight toSize:self.quotedAttachmentSize];
        [quotedAttachmentView setContentHuggingHigh];
        [quotedAttachmentView setCompressionResistanceHigh];

        // TODO: Consider stroking the quoted thumbnail.
    }

    OWSContactsManager *contactsManager = Environment.current.contactsManager;
    NSString *quotedAuthor = [contactsManager displayNameForPhoneIdentifier:self.quotedMessage.authorId];

    UILabel *quotedAuthorLabel = [UILabel new];
    {
        quotedAuthorLabel.text = quotedAuthor;
        quotedAuthorLabel.font = self.quotedAuthorFont;
        // TODO:
        quotedAuthorLabel.textColor = [UIColor ows_darkGrayColor];
        //            = (self.isIncoming ? [UIColor colorWithRGBHex:0xd84315] : [UIColor colorWithRGBHex:0x007884]);
        quotedAuthorLabel.numberOfLines = 1;
        quotedAuthorLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:quotedAuthorLabel];
        [quotedAuthorLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:self.quotedAuthorTopInset];
        [quotedAuthorLabel autoPinLeadingToSuperviewMarginWithInset:self.quotedContentHInset];
        if (quotedAttachmentView) {
            [quotedAuthorLabel autoPinTrailingToLeadingEdgeOfView:quotedAttachmentView
                                                           offset:self.quotedAttachmentHSpacing];
        } else {
            [quotedAuthorLabel autoPinTrailingToSuperviewMarginWithInset:self.quotedContentHInset];
        }
        [quotedAuthorLabel autoSetDimension:ALDimensionHeight toSize:self.quotedAuthorHeight];
        [quotedAuthorLabel setContentHuggingLow];
        [quotedAuthorLabel setCompressionResistanceLow];
    }

    {
        // Stripe and text container.
        UIView *stripeAndTextContainer = [UIView containerView];
        [self addSubview:stripeAndTextContainer];
        [stripeAndTextContainer autoPinEdge:ALEdgeTop
                                     toEdge:ALEdgeBottom
                                     ofView:quotedAuthorLabel
                                 withOffset:self.quotedAuthorBottomSpacing];
        [stripeAndTextContainer autoPinLeadingToSuperviewMarginWithInset:self.quotedContentHInset];
        if (quotedAttachmentView) {
            [stripeAndTextContainer autoPinTrailingToLeadingEdgeOfView:quotedAttachmentView
                                                                offset:self.quotedAttachmentHSpacing];
        } else {
            [stripeAndTextContainer autoPinTrailingToSuperviewMarginWithInset:self.quotedContentHInset];
        }
        [stripeAndTextContainer autoPinBottomToSuperviewMarginWithInset:self.quotedContentHInset];
        [stripeAndTextContainer setContentHuggingLow];
        [stripeAndTextContainer setCompressionResistanceLow];

        // Stripe.
        BOOL isIncomingQuote
            = ![NSObject isNullableObject:self.quotedMessage.authorId equalTo:TSAccountManager.localNumber];
        UIColor *stripeColor = (isIncomingQuote ? OWSMessagesBubbleImageFactory.bubbleColorIncoming
                                                : OWSMessagesBubbleImageFactory.bubbleColorOutgoingSent);
        UIView *quoteStripView = [UIView containerView];
        quoteStripView.backgroundColor = stripeColor;
        quoteStripView.userInteractionEnabled = NO;
        [stripeAndTextContainer addSubview:quoteStripView];
        [quoteStripView autoPinHeightToSuperview];
        [quoteStripView autoPinLeadingToSuperviewMargin];
        [quoteStripView autoSetDimension:ALDimensionWidth toSize:self.quotedReplyStripeThickness];
        [quoteStripView setContentHuggingVerticalLow];
        [quoteStripView setContentHuggingHorizontalHigh];
        [quoteStripView setCompressionResistanceHigh];

        // Text.
        UILabel *quotedTextLabel = [self createQuotedTextLabel];
        [stripeAndTextContainer addSubview:quotedTextLabel];
        [quotedTextLabel autoPinTopToSuperviewMarginWithInset:self.quotedReplyStripeVExtension];
        [quotedTextLabel autoPinBottomToSuperviewMarginWithInset:self.quotedReplyStripeVExtension];
        [quotedTextLabel autoPinLeadingToTrailingEdgeOfView:quoteStripView offset:self.quotedReplyStripeHSpacing];
        [quotedTextLabel autoPinTrailingToSuperviewMargin];
        [quotedTextLabel setContentHuggingLow];
        [quotedTextLabel setCompressionResistanceLow];
    }
}

#pragma mark - Measurement

// TODO: Class method?
- (CGSize)sizeForMaxWidth:(CGFloat)maxWidth
{
    CGSize result = CGSizeZero;

    result.width += self.quotedContentHInset;

    CGFloat thumbnailHeight = 0.f;
    if (self.hasQuotedAttachmentThumbnail) {
        result.width += self.quotedAttachmentHSpacing;
        result.width += self.quotedAttachmentSize;

        thumbnailHeight += self.quotedAttachmentMinVInset;
        thumbnailHeight += self.quotedAttachmentSize;
        thumbnailHeight += self.quotedAttachmentMinVInset;
    }

    result.width += self.quotedContentHInset;

    // Quoted Author
    CGFloat quotedAuthorWidth = 0.f;
    {
        CGFloat maxQuotedAuthorWidth = maxWidth - result.width;

        OWSContactsManager *contactsManager = Environment.current.contactsManager;
        NSString *quotedAuthor = [contactsManager displayNameForPhoneIdentifier:self.quotedMessage.authorId];

        UILabel *quotedAuthorLabel = [UILabel new];
        quotedAuthorLabel.text = quotedAuthor;
        quotedAuthorLabel.font = self.quotedAuthorFont;
        quotedAuthorLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        quotedAuthorLabel.numberOfLines = 1;

        CGSize quotedAuthorSize
            = CGSizeCeil([quotedAuthorLabel sizeThatFits:CGSizeMake(maxQuotedAuthorWidth, CGFLOAT_MAX)]);

        quotedAuthorWidth = quotedAuthorSize.width;

        result.height += self.quotedAuthorTopInset;
        result.height += self.quotedAuthorHeight;
        result.height += self.quotedAuthorBottomSpacing;
    }

    CGFloat quotedTextWidth = 0.f;
    {
        CGFloat maxQuotedTextWidth
            = (maxWidth - (result.width + self.quotedReplyStripeThickness + self.quotedReplyStripeHSpacing));

        UILabel *quotedTextLabel = [self createQuotedTextLabel];

        CGSize textSize = CGSizeCeil([quotedTextLabel sizeThatFits:CGSizeMake(maxQuotedTextWidth, CGFLOAT_MAX)]);

        quotedTextWidth = textSize.width + self.quotedReplyStripeThickness + self.quotedReplyStripeHSpacing;
        result.height += self.quotedAuthorBottomSpacing;
        result.height += textSize.height + self.quotedReplyStripeVExtension * 2;
    }

    CGFloat textWidth = MAX(quotedAuthorWidth, quotedTextWidth);
    result.width += textWidth;

    result.height += self.quotedTextBottomInset;
    result.height = MAX(result.height, thumbnailHeight);

    return result;
}

- (UILabel *)createQuotedTextLabel
{
    UILabel *quotedTextLabel = [UILabel new];
    quotedTextLabel.numberOfLines = 3;
    quotedTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    quotedTextLabel.text = self.quotedSnippet;
    quotedTextLabel.textColor = self.quotedTextColor;

    // Honor dynamic type in the message bodies.
    quotedTextLabel.font = self.textMessageFont;
    return quotedTextLabel;
}

- (UIColor *)quotedTextColor
{
    return [UIColor blackColor];
}

- (NSString *)quotedSnippet
{
    if (self.displayableQuotedText.displayText.length > 0) {
        return self.displayableQuotedText.displayText;
    } else {
        NSString *mimeType = self.quotedMessage.contentType;

        if (mimeType.length > 0) {
            return [TSAttachment emojiForMimeType:mimeType];
        }
    }

    return @"";
}

// TODO:
- (UIFont *)quotedAuthorFont
{
    return [UIFont ows_regularFontWithSize:10.f];
}

// TODO:
- (CGFloat)quotedAuthorHeight
{
    return (CGFloat)ceil([self quotedAuthorFont].lineHeight * 1.f);
}

// TODO:
- (CGFloat)quotedAuthorTopInset
{
    return 4.f;
}

// TODO:
- (CGFloat)quotedAuthorBottomSpacing
{
    return 2.f;
}

// TODO:
- (CGFloat)quotedTextBottomInset
{
    return 5.f;
}

// TODO:
- (CGFloat)quotedReplyStripeThickness
{
    return 2.f;
}

// TODO:
- (CGFloat)quotedReplyStripeVExtension
{
    return 5.f;
}

// The spacing between the vertical "quoted reply stripe"
// and the quoted message content.
// TODO:
- (CGFloat)quotedReplyStripeHSpacing
{
    return 8.f;
}

// Distance from top edge of "quoted message" bubble to top of message bubble.
// TODO:
- (CGFloat)quotedAttachmentMinVInset
{
    return 10.f;
}

// TODO:
- (CGFloat)quotedAttachmentSize
{
    return 30.f;
}

// TODO:
- (CGFloat)quotedAttachmentHSpacing
{
    return 10.f;
}

// Distance from sides of the quoted content to the sides of the message bubble.
// TODO:
- (CGFloat)quotedContentHInset
{
    return 8.f;
}

#pragma mark - Stroke

//- (instancetype)init
//{
//    self = [super init];
//    if (!self) {
//        return self;
//    }
//
//    self.opaque = NO;
//    self.backgroundColor = [UIColor clearColor];
//
//
//    [self updateLayers];
//
//    return self;
//}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;

    [self updateLayers];
}

- (void)setStrokeThickness:(CGFloat)strokeThickness
{
    _strokeThickness = strokeThickness;

    [self updateLayers];
}

- (void)setFrame:(CGRect)frame
{
    BOOL didChange = !CGRectEqualToRect(self.frame, frame);

    [super setFrame:frame];

    if (didChange) {
        [self updateLayers];
    }
}

- (void)setBounds:(CGRect)bounds
{
    BOOL didChange = !CGRectEqualToRect(self.bounds, bounds);

    [super setBounds:bounds];

    if (didChange) {
        [self updateLayers];
    }
}

- (void)setCenter:(CGPoint)center
{
    [super setCenter:center];

    [self updateLayers];
}

- (void)updateLayers
{
    if (!self.shapeLayer) {
        return;
    }

    // Don't fill the shape layer; we just want a stroke around the border.
    self.shapeLayer.fillColor = [UIColor clearColor].CGColor;

    self.clipsToBounds = YES;

    if (!self.bubbleView) {
        return;
    }

    self.shapeLayer.strokeColor = self.strokeColor.CGColor;
    self.shapeLayer.lineWidth = self.strokeThickness;
    self.shapeLayer.zPosition = 100.f;

    UIBezierPath *bezierPath = [UIBezierPath new];

    UIBezierPath *boundsBezierPath = [UIBezierPath bezierPathWithRect:self.bounds];
    [bezierPath appendPath:boundsBezierPath];

    UIBezierPath *bubbleBezierPath = [self.bubbleView maskPath];
    // We need to convert between coordinate systems using layers, not views.
    CGPoint bubbleOffset = [self.layer convertPoint:CGPointZero fromLayer:self.bubbleView.layer];
    CGAffineTransform transform = CGAffineTransformMakeTranslation(bubbleOffset.x, bubbleOffset.y);
    [bubbleBezierPath applyTransform:transform];
    [bezierPath appendPath:bubbleBezierPath];

    self.shapeLayer.path = bezierPath.CGPath;
}

@end

NS_ASSUME_NONNULL_END
