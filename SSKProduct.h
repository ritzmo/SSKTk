//
//  SSKProduct.h
//  dreaMote
//
//  Created by Moritz Venn on 09.12.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "SSKConfig.h"

typedef void (^productCompletionHandler_t)(BOOL success);
typedef void (^productErrorHandler_t)(NSError *error);

@interface SSKProduct : NSObject

/*!
 @brief Create a new wrapper for a SKProduct.
 Used internally instead of regular SKProducts for convenience.
 @param product
 @return
 */
+ (SSKProduct *)withProduct:(SKProduct *)product;

/*!
 @brief Create a new wrapper for a SKProduct.
 Use this initializer for subscriptions.
 @param product
 @param days
 @return
 */
+ (SSKProduct *)subscriptionWithProduct:(SKProduct *)product validForDays:(NSInteger)days;

#if defined(REVIEW_ALLOWED)
/*!
 @brief Check if review is allowed for this product.
 @param completionHandler
 @param errorHandler
 @return
 */
- (void)reviewRequestCompletionHandler:(productCompletionHandler_t)completionHandler errorHandler:(productErrorHandler_t)errorHandler;
#endif

/*!
 @brief Check if a given receipt is valid.
 @note Does not validate if the receipt is for a certain product.
 @param receipt
 @param completionHandler
 @param errorHandler
 @return
 */
- (void)verifyReceipt:(NSData *)receipt onComplete:(productCompletionHandler_t)completionHandler errorHandler:(productErrorHandler_t)errorHandler;

/*!
 @brief String representation for this product.
 Can be used in the GUI.
 @return
 */
- (NSString *)stringValue;

/*!
 @brief Product identifier.
 */
@property (nonatomic, readonly) NSString *productIdentifier;

/*!
 @brief Is this subscription active?
 @note Return is undefined if product is not actually a subscription product.
 */
@property (nonatomic, readonly) BOOL subscriptionActive;

@end
