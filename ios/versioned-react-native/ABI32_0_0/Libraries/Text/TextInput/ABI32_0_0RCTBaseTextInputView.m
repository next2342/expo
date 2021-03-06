/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI32_0_0RCTBaseTextInputView.h"

#import <ReactABI32_0_0/ABI32_0_0RCTAccessibilityManager.h>
#import <ReactABI32_0_0/ABI32_0_0RCTBridge.h>
#import <ReactABI32_0_0/ABI32_0_0RCTConvert.h>
#import <ReactABI32_0_0/ABI32_0_0RCTEventDispatcher.h>
#import <ReactABI32_0_0/ABI32_0_0RCTUIManager.h>
#import <ReactABI32_0_0/ABI32_0_0RCTUtils.h>
#import <ReactABI32_0_0/UIView+ReactABI32_0_0.h>

#import "ABI32_0_0RCTInputAccessoryView.h"
#import "ABI32_0_0RCTInputAccessoryViewContent.h"
#import "ABI32_0_0RCTTextAttributes.h"
#import "ABI32_0_0RCTTextSelection.h"

@implementation ABI32_0_0RCTBaseTextInputView {
  __weak ABI32_0_0RCTBridge *_bridge;
  __weak ABI32_0_0RCTEventDispatcher *_eventDispatcher;
  BOOL _hasInputAccesoryView;
  NSString *_Nullable _predictedText;
  NSInteger _nativeEventCount;
}

- (instancetype)initWithBridge:(ABI32_0_0RCTBridge *)bridge
{
  ABI32_0_0RCTAssertParam(bridge);

  if (self = [super initWithFrame:CGRectZero]) {
    _bridge = bridge;
    _eventDispatcher = bridge.eventDispatcher;
  }

  return self;
}

ABI32_0_0RCT_NOT_IMPLEMENTED(- (instancetype)init)
ABI32_0_0RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)decoder)
ABI32_0_0RCT_NOT_IMPLEMENTED(- (instancetype)initWithFrame:(CGRect)frame)

- (UIView<ABI32_0_0RCTBackedTextInputViewProtocol> *)backedTextInputView
{
  ABI32_0_0RCTAssert(NO, @"-[ABI32_0_0RCTBaseTextInputView backedTextInputView] must be implemented in subclass.");
  return nil;
}

#pragma mark - ABI32_0_0RCTComponent

- (void)didUpdateReactABI32_0_0Subviews
{
  // Do nothing.
}

#pragma mark - Properties

- (void)setTextAttributes:(ABI32_0_0RCTTextAttributes *)textAttributes
{
  _textAttributes = textAttributes;
  [self enforceTextAttributesIfNeeded];
}

- (void)enforceTextAttributesIfNeeded
{
  id<ABI32_0_0RCTBackedTextInputViewProtocol> backedTextInputView = self.backedTextInputView;
  if (backedTextInputView.attributedText.string.length != 0) {
    return;
  }

  backedTextInputView.font = _textAttributes.effectiveFont;
  backedTextInputView.textColor = _textAttributes.effectiveForegroundColor;
  backedTextInputView.textAlignment = _textAttributes.alignment;
}

- (void)setReactABI32_0_0PaddingInsets:(UIEdgeInsets)ReactABI32_0_0PaddingInsets
{
  _ReactABI32_0_0PaddingInsets = ReactABI32_0_0PaddingInsets;
  // We apply `paddingInsets` as `backedTextInputView`'s `textContainerInset`.
  self.backedTextInputView.textContainerInset = ReactABI32_0_0PaddingInsets;
  [self setNeedsLayout];
}

- (void)setReactABI32_0_0BorderInsets:(UIEdgeInsets)ReactABI32_0_0BorderInsets
{
  _ReactABI32_0_0BorderInsets = ReactABI32_0_0BorderInsets;
  // We apply `borderInsets` as `backedTextInputView` layout offset.
  self.backedTextInputView.frame = UIEdgeInsetsInsetRect(self.bounds, ReactABI32_0_0BorderInsets);
  [self setNeedsLayout];
}

- (NSAttributedString *)attributedText
{
  return self.backedTextInputView.attributedText;
}

- (BOOL)textOf:(NSAttributedString*)newText equals:(NSAttributedString*)oldText{
  // When the dictation is running we can't update the attibuted text on the backed up text view
  // because setting the attributed string will kill the dictation. This means that we can't impose
  // the settings on a dictation.
  // Similarly, when the user is in the middle of inputting some text in Japanese/Chinese, there will be styling on the
  // text that we should disregard. See https://developer.apple.com/documentation/uikit/uitextinput/1614489-markedtextrange?language=objc
  // for more info.
  // Lastly, when entering a password, etc., there will be additional styling on the field as the native text view
  // handles showing the last character for a split second.
  BOOL shouldFallbackToBareTextComparison =
    [self.backedTextInputView.textInputMode.primaryLanguage isEqualToString:@"dictation"] ||
    self.backedTextInputView.markedTextRange ||
    self.backedTextInputView.isSecureTextEntry;
  if (shouldFallbackToBareTextComparison) {
    return ([newText.string isEqualToString:oldText.string]);
  } else {
    return ([newText isEqualToAttributedString:oldText]);
  }
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  NSInteger eventLag = _nativeEventCount - _mostRecentEventCount;
  BOOL textNeedsUpdate = NO;
  // Remove tag attribute to ensure correct attributed string comparison.
  NSMutableAttributedString *const backedTextInputViewTextCopy = [self.backedTextInputView.attributedText mutableCopy];
  NSMutableAttributedString *const attributedTextCopy = [attributedText mutableCopy];

  [backedTextInputViewTextCopy removeAttribute:ABI32_0_0RCTTextAttributesTagAttributeName
                                         range:NSMakeRange(0, backedTextInputViewTextCopy.length)];

  [attributedTextCopy removeAttribute:ABI32_0_0RCTTextAttributesTagAttributeName
                                range:NSMakeRange(0, attributedTextCopy.length)];
  
  textNeedsUpdate = ([self textOf:attributedTextCopy equals:backedTextInputViewTextCopy] == NO);
  
  if (eventLag == 0 && textNeedsUpdate) {
    UITextRange *selection = self.backedTextInputView.selectedTextRange;
    NSInteger oldTextLength = self.backedTextInputView.attributedText.string.length;

    self.backedTextInputView.attributedText = attributedText;

    if (selection.empty) {
      // Maintaining a cursor position relative to the end of the old text.
      NSInteger offsetStart =
      [self.backedTextInputView offsetFromPosition:self.backedTextInputView.beginningOfDocument
                                        toPosition:selection.start];
      NSInteger offsetFromEnd = oldTextLength - offsetStart;
      NSInteger newOffset = attributedText.string.length - offsetFromEnd;
      UITextPosition *position =
      [self.backedTextInputView positionFromPosition:self.backedTextInputView.beginningOfDocument
                                              offset:newOffset];
      [self.backedTextInputView setSelectedTextRange:[self.backedTextInputView textRangeFromPosition:position toPosition:position]
                                      notifyDelegate:YES];
    }

    [self updateLocalData];
  } else if (eventLag > ABI32_0_0RCTTextUpdateLagWarningThreshold) {
    ABI32_0_0RCTLogWarn(@"Native TextInput(%@) is %lld events ahead of JS - try to make your JS faster.", self.backedTextInputView.attributedText.string, (long long)eventLag);
  }
}

- (ABI32_0_0RCTTextSelection *)selection
{
  id<ABI32_0_0RCTBackedTextInputViewProtocol> backedTextInputView = self.backedTextInputView;
  UITextRange *selectedTextRange = backedTextInputView.selectedTextRange;
  return [[ABI32_0_0RCTTextSelection new] initWithStart:[backedTextInputView offsetFromPosition:backedTextInputView.beginningOfDocument toPosition:selectedTextRange.start]
                                           end:[backedTextInputView offsetFromPosition:backedTextInputView.beginningOfDocument toPosition:selectedTextRange.end]];
}

- (void)setSelection:(ABI32_0_0RCTTextSelection *)selection
{
  if (!selection) {
    return;
  }

  id<ABI32_0_0RCTBackedTextInputViewProtocol> backedTextInputView = self.backedTextInputView;

  UITextRange *previousSelectedTextRange = backedTextInputView.selectedTextRange;
  UITextPosition *start = [backedTextInputView positionFromPosition:backedTextInputView.beginningOfDocument offset:selection.start];
  UITextPosition *end = [backedTextInputView positionFromPosition:backedTextInputView.beginningOfDocument offset:selection.end];
  UITextRange *selectedTextRange = [backedTextInputView textRangeFromPosition:start toPosition:end];

  NSInteger eventLag = _nativeEventCount - _mostRecentEventCount;
  if (eventLag == 0 && ![previousSelectedTextRange isEqual:selectedTextRange]) {
    [backedTextInputView setSelectedTextRange:selectedTextRange notifyDelegate:NO];
  } else if (eventLag > ABI32_0_0RCTTextUpdateLagWarningThreshold) {
    ABI32_0_0RCTLogWarn(@"Native TextInput(%@) is %lld events ahead of JS - try to make your JS faster.", backedTextInputView.attributedText.string, (long long)eventLag);
  }
}

- (void)setTextContentType:(NSString *)type
{
  #if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    if (@available(iOS 10.0, *)) {
        // Setting textContentType to an empty string will disable any
        // default behaviour, like the autofill bar for password inputs
        self.backedTextInputView.textContentType = [type isEqualToString:@"none"] ? @"" : type;
    }
  #endif
}

- (UIKeyboardType)keyboardType
{
  return self.backedTextInputView.keyboardType;
}

- (void)setKeyboardType:(UIKeyboardType)keyboardType
{
  UIView<ABI32_0_0RCTBackedTextInputViewProtocol> *textInputView = self.backedTextInputView;
  if (textInputView.keyboardType != keyboardType) {
    textInputView.keyboardType = keyboardType;
    // Without the call to reloadInputViews, the keyboard will not change until the textview field (the first responder) loses and regains focus.
    if (textInputView.isFirstResponder) {
      [textInputView reloadInputViews];
    }
  }
}

#pragma mark - ABI32_0_0RCTBackedTextInputDelegate

- (BOOL)textInputShouldBeginEditing
{
  return YES;
}

- (void)textInputDidBeginEditing
{
  if (_clearTextOnFocus) {
    self.backedTextInputView.attributedText = [NSAttributedString new];
  }

  if (_selectTextOnFocus) {
    [self.backedTextInputView selectAll:nil];
  }

  [_eventDispatcher sendTextEventWithType:ABI32_0_0RCTTextEventTypeFocus
                                 ReactABI32_0_0Tag:self.ReactABI32_0_0Tag
                                     text:self.backedTextInputView.attributedText.string
                                      key:nil
                               eventCount:_nativeEventCount];
}

- (BOOL)textInputShouldEndEditing
{
  return YES;
}

- (void)textInputDidEndEditing
{
  [_eventDispatcher sendTextEventWithType:ABI32_0_0RCTTextEventTypeEnd
                                 ReactABI32_0_0Tag:self.ReactABI32_0_0Tag
                                     text:self.backedTextInputView.attributedText.string
                                      key:nil
                               eventCount:_nativeEventCount];

  [_eventDispatcher sendTextEventWithType:ABI32_0_0RCTTextEventTypeBlur
                                 ReactABI32_0_0Tag:self.ReactABI32_0_0Tag
                                     text:self.backedTextInputView.attributedText.string
                                      key:nil
                               eventCount:_nativeEventCount];
}

- (BOOL)textInputShouldReturn
{
  // We send `submit` event here, in `textInputShouldReturn`
  // (not in `textInputDidReturn)`, because of semantic of the event:
  // `onSubmitEditing` is called when "Submit" button
  // (the blue key on onscreen keyboard) did pressed
  // (no connection to any specific "submitting" process).
  [_eventDispatcher sendTextEventWithType:ABI32_0_0RCTTextEventTypeSubmit
                                 ReactABI32_0_0Tag:self.ReactABI32_0_0Tag
                                     text:self.backedTextInputView.attributedText.string
                                      key:nil
                               eventCount:_nativeEventCount];

  return _blurOnSubmit;
}

- (void)textInputDidReturn
{
  // Does nothing.
}

- (BOOL)textInputShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  id<ABI32_0_0RCTBackedTextInputViewProtocol> backedTextInputView = self.backedTextInputView;

  if (!backedTextInputView.textWasPasted) {
    [_eventDispatcher sendTextEventWithType:ABI32_0_0RCTTextEventTypeKeyPress
                                   ReactABI32_0_0Tag:self.ReactABI32_0_0Tag
                                       text:nil
                                        key:text
                                 eventCount:_nativeEventCount];
  }

  if (_maxLength) {
    NSUInteger allowedLength = _maxLength.integerValue - backedTextInputView.attributedText.string.length + range.length;

    if (text.length > allowedLength) {
      // If we typed/pasted more than one character, limit the text inputted.
      if (text.length > 1) {
        // Truncate the input string so the result is exactly maxLength
        NSString *limitedString = [text substringToIndex:allowedLength];
        NSMutableAttributedString *newAttributedText = [backedTextInputView.attributedText mutableCopy];
        [newAttributedText replaceCharactersInRange:range withString:limitedString];
        backedTextInputView.attributedText = newAttributedText;
        _predictedText = newAttributedText.string;

        // Collapse selection at end of insert to match normal paste behavior.
        UITextPosition *insertEnd = [backedTextInputView positionFromPosition:backedTextInputView.beginningOfDocument
                                                                       offset:(range.location + allowedLength)];
        [backedTextInputView setSelectedTextRange:[backedTextInputView textRangeFromPosition:insertEnd toPosition:insertEnd]
                                   notifyDelegate:YES];

        [self textInputDidChange];
      }

      return NO;
    }
  }

  if (range.location + range.length > _predictedText.length) {
    // _predictedText got out of sync in a bad way, so let's just force sync it.  Haven't been able to repro this, but
    // it's causing a real crash here: #6523822
    _predictedText = backedTextInputView.attributedText.string;
  }

  NSString *previousText = [_predictedText substringWithRange:range] ?: @"";

  // After clearing the text by replacing it with an empty string, `_predictedText`
  // still preserves the deleted text.
  // As the first character in the TextInput always comes with the range value (0, 0),
  // we should check the range value in order to avoid appending a character to the deleted string
  // (which caused the issue #18374)
  if (!NSEqualRanges(range, NSMakeRange(0, 0)) && _predictedText) {
    _predictedText = [_predictedText stringByReplacingCharactersInRange:range withString:text];
  } else {
    _predictedText = text;
  }

  if (_onTextInput) {
    _onTextInput(@{
      @"text": text,
      @"previousText": previousText,
      @"range": @{
        @"start": @(range.location),
        @"end": @(range.location + range.length)
      },
      @"eventCount": @(_nativeEventCount),
    });
  }

  return YES;
}

- (void)textInputDidChange
{
  [self updateLocalData];

  id<ABI32_0_0RCTBackedTextInputViewProtocol> backedTextInputView = self.backedTextInputView;

  // Detect when `backedTextInputView` updates happend that didn't invoke `shouldChangeTextInRange`
  // (e.g. typing simplified chinese in pinyin will insert and remove spaces without
  // calling shouldChangeTextInRange).  This will cause JS to get out of sync so we
  // update the mismatched range.
  NSRange currentRange;
  NSRange predictionRange;
  if (findMismatch(backedTextInputView.attributedText.string, _predictedText, &currentRange, &predictionRange)) {
    NSString *replacement = [backedTextInputView.attributedText.string substringWithRange:currentRange];
    [self textInputShouldChangeTextInRange:predictionRange replacementText:replacement];
    // JS will assume the selection changed based on the location of our shouldChangeTextInRange, so reset it.
    [self textInputDidChangeSelection];
    _predictedText = backedTextInputView.attributedText.string;
  }

  _nativeEventCount++;

  if (_onChange) {
    _onChange(@{
       @"text": self.attributedText.string,
       @"target": self.ReactABI32_0_0Tag,
       @"eventCount": @(_nativeEventCount),
    });
  }
}

- (void)textInputDidChangeSelection
{
  if (!_onSelectionChange) {
    return;
  }

  ABI32_0_0RCTTextSelection *selection = self.selection;

  _onSelectionChange(@{
    @"selection": @{
      @"start": @(selection.start),
      @"end": @(selection.end),
    },
  });
}

- (void)updateLocalData
{
  [self enforceTextAttributesIfNeeded];

  [_bridge.uiManager setLocalData:[self.backedTextInputView.attributedText copy]
                          forView:self];
}

#pragma mark - Layout (in UIKit terms, with all insets)

- (CGSize)intrinsicContentSize
{
  CGSize size = self.backedTextInputView.intrinsicContentSize;
  size.width += _ReactABI32_0_0BorderInsets.left + _ReactABI32_0_0BorderInsets.right;
  size.height += _ReactABI32_0_0BorderInsets.top + _ReactABI32_0_0BorderInsets.bottom;
  // Returning value DOES include border and padding insets.
  return size;
}

- (CGSize)sizeThatFits:(CGSize)size
{
  CGFloat compoundHorizontalBorderInset = _ReactABI32_0_0BorderInsets.left + _ReactABI32_0_0BorderInsets.right;
  CGFloat compoundVerticalBorderInset = _ReactABI32_0_0BorderInsets.top + _ReactABI32_0_0BorderInsets.bottom;

  size.width -= compoundHorizontalBorderInset;
  size.height -= compoundVerticalBorderInset;

  // Note: `paddingInsets` was already included in `backedTextInputView` size
  // because it was applied as `textContainerInset`.
  CGSize fittingSize = [self.backedTextInputView sizeThatFits:size];

  fittingSize.width += compoundHorizontalBorderInset;
  fittingSize.height += compoundVerticalBorderInset;

  // Returning value DOES include border and padding insets.
  return fittingSize;
}

#pragma mark - Accessibility

- (UIView *)ReactABI32_0_0AccessibilityElement
{
  return self.backedTextInputView;
}

#pragma mark - Focus Control

- (void)ReactABI32_0_0Focus
{
  [self.backedTextInputView ReactABI32_0_0Focus];
}

- (void)ReactABI32_0_0Blur
{
  [self.backedTextInputView ReactABI32_0_0Blur];
}

- (void)didMoveToWindow
{
  [self.backedTextInputView ReactABI32_0_0FocusIfNeeded];
}

#pragma mark - Custom Input Accessory View

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  if ([changedProps containsObject:@"inputAccessoryViewID"] && self.inputAccessoryViewID) {
    [self setCustomInputAccessoryViewWithNativeID:self.inputAccessoryViewID];
  } else if (!self.inputAccessoryViewID) {
    [self setDefaultInputAccessoryView];
  }
}

- (void)setCustomInputAccessoryViewWithNativeID:(NSString *)nativeID
{
  #if !TARGET_OS_TV
  __weak ABI32_0_0RCTBaseTextInputView *weakSelf = self;
  [_bridge.uiManager rootViewForReactABI32_0_0Tag:self.ReactABI32_0_0Tag withCompletion:^(UIView *rootView) {
    ABI32_0_0RCTBaseTextInputView *strongSelf = weakSelf;
    if (rootView) {
      UIView *accessoryView = [strongSelf->_bridge.uiManager viewForNativeID:nativeID
                                                                 withRootTag:rootView.ReactABI32_0_0Tag];
      if (accessoryView && [accessoryView isKindOfClass:[ABI32_0_0RCTInputAccessoryView class]]) {
        strongSelf.backedTextInputView.inputAccessoryView = ((ABI32_0_0RCTInputAccessoryView *)accessoryView).inputAccessoryView;
        [strongSelf reloadInputViewsIfNecessary];
      }
    }
  }];
  #endif /* !TARGET_OS_TV */
}

- (void)setDefaultInputAccessoryView
{
  #if !TARGET_OS_TV
  UIView<ABI32_0_0RCTBackedTextInputViewProtocol> *textInputView = self.backedTextInputView;
  UIKeyboardType keyboardType = textInputView.keyboardType;

  // These keyboard types (all are number pads) don't have a "Done" button by default,
  // so we create an `inputAccessoryView` with this button for them.
  BOOL shouldHaveInputAccesoryView =
    (
      keyboardType == UIKeyboardTypeNumberPad ||
      keyboardType == UIKeyboardTypePhonePad ||
      keyboardType == UIKeyboardTypeDecimalPad ||
      keyboardType == UIKeyboardTypeASCIICapableNumberPad
    ) &&
    textInputView.returnKeyType == UIReturnKeyDone;

  if (_hasInputAccesoryView == shouldHaveInputAccesoryView) {
    return;
  }

  _hasInputAccesoryView = shouldHaveInputAccesoryView;

  if (shouldHaveInputAccesoryView) {
    UIToolbar *toolbarView = [[UIToolbar alloc] init];
    [toolbarView sizeToFit];
    UIBarButtonItem *flexibleSpace =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                    target:nil
                                                    action:nil];
    UIBarButtonItem *doneButton =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                    target:self
                                                    action:@selector(handleInputAccessoryDoneButton)];
    toolbarView.items = @[flexibleSpace, doneButton];
    textInputView.inputAccessoryView = toolbarView;
  }
  else {
    textInputView.inputAccessoryView = nil;
  }
  [self reloadInputViewsIfNecessary];
  #endif /* !TARGET_OS_TV */
}

- (void)reloadInputViewsIfNecessary
{
  // We have to call `reloadInputViews` for focused text inputs to update an accessory view.
  if (self.backedTextInputView.isFirstResponder) {
    [self.backedTextInputView reloadInputViews];
  }
}

- (void)handleInputAccessoryDoneButton
{
  if ([self textInputShouldReturn]) {
    [self.backedTextInputView endEditing:YES];
  }
}

#pragma mark - Helpers

static BOOL findMismatch(NSString *first, NSString *second, NSRange *firstRange, NSRange *secondRange)
{
  NSInteger firstMismatch = -1;
  for (NSUInteger ii = 0; ii < MAX(first.length, second.length); ii++) {
    if (ii >= first.length || ii >= second.length || [first characterAtIndex:ii] != [second characterAtIndex:ii]) {
      firstMismatch = ii;
      break;
    }
  }

  if (firstMismatch == -1) {
    return NO;
  }

  NSUInteger ii = second.length;
  NSUInteger lastMismatch = first.length;
  while (ii > firstMismatch && lastMismatch > firstMismatch) {
    if ([first characterAtIndex:(lastMismatch - 1)] != [second characterAtIndex:(ii - 1)]) {
      break;
    }
    ii--;
    lastMismatch--;
  }

  *firstRange = NSMakeRange(firstMismatch, lastMismatch - firstMismatch);
  *secondRange = NSMakeRange(firstMismatch, ii - firstMismatch);
  return YES;
}

@end
