//
//  SSKManager.h
//  dreaMote
//
//  Created by Moritz Venn on 09.12.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "SSKProduct.h"
#import "SSKConfig.h"

typedef void (^completionHandler_t)(NSString *productIdentifier);
typedef void (^cancelHandler_t)(NSString *productIdentifier);
typedef void (^errorHandler_t)(NSString *productIdentifier, NSError *error);

extern NSString *sskErrorDomain;

extern NSString *kProductsFetchedNotification;
extern NSString *kSubscriptionInvalidNotification;
extern NSString *kProductReceiptInvalidNotification;

// compatibility to MKStoreKit
#define kProductFetchedNotification kProductsFetchedNotification
#define kSubscriptionsInvalidNotification kSubscriptionInvalidNotification

@interface SSKManager : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>
/*!
 @brief Get Singleton.
 */
+ (SSKManager *)sharedManager;

/*!
 @brief Start verifying products with the AppStore.
 @param dictionary
 */
- (void)lookForProducts:(NSDictionary *)dictionary;

/*!
 @brief Copy over old entries from MKStoreKit to SSKManager.
 @note Currently just copies the entries over so we don't have to force users to "repurchase", in the future we delete the old entries.
 */
- (void)portFromMKStoreKit;

/*!
 @brief Remove all product data from keychain.
 Useful when debugging.
 */
- (BOOL)removeAllKeychainData;

/*!
 @brief Check if a product was previously purchases.
 @param productIdentifier
 @return
 */
+ (BOOL)isFeaturePurchased:(NSString *)productIdentifier;

/*!
 @brief Attempt to redeem code for purchase.
 Basically the same as [SSKManager reddemCode:forProduct:completionHandler:errorHandler] but without requiring the proper product.
 @param code
 @param productIdentifier
 @param completionHandler
 @param errorHandler
 */
- (void)redeemCode:(NSString *)code forProductIdentifier:(NSString *)productIdentifier completionHandler:(completionHandler_t)completionHandler errorHandler:(errorHandler_t)errorHandler;

/*!
 @brief Attempt to redeem code for purchase.
 @param code
 @param product
 @param completionHandler
 @param errorHandler
 */
- (void)redeemCode:(NSString *)code forProduct:(SSKProduct *)product completionHandler:(completionHandler_t)completionHandler errorHandler:(errorHandler_t)errorHandler;

/*!
 @brief Initiate purchase for a given product identifier.
 @note Multiple purchases may happen at once, but a product can not be queued multiple times simultaneously.
 @param product
 @param completionHandler
 @param cancelHandler
 @param errorHandler
 */
- (void)buyProduct:(SSKProduct *)product completionHandler:(completionHandler_t)completionHandler cancelHandler:(cancelHandler_t)cancelHandler errorHandler:(errorHandler_t)errorHandler;

/*!
 @brief Restore previous purchases.
 @param completionHandler
 @param errorHandler
 */
- (void)restorePreviousPurchasesOnComplete:(completionHandler_t)completionHandler onError:(errorHandler_t)errorHandler;

/*!
 @brief Override Uuid to be used for review.
 */
@property (nonatomic, strong) NSString *uuidForReview;

/*!
 @brief List of purchasable objects.
 */
@property (nonatomic, readonly) NSArray *purchasables;

@end
