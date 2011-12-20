//
//  SSKManager.m
//  dreaMote
//
//  Created by Moritz Venn on 09.12.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import "SSKManager.h"

#import "SFHFKeychainUtils.h"

#pragma mark - Helper product for redeeming codes without knowing the proper product

@interface SSKBlindProduct : SSKProduct
{
@private
	NSString *productIdentifier;
}
+ (SSKProduct *)productWithIdentifier:(NSString *)productIdentifier;
@end

@implementation SSKBlindProduct
+ (SSKProduct *)productWithIdentifier:(NSString *)productIdentifier
{
	SSKBlindProduct *prod = [[SSKBlindProduct alloc] init];
	prod->productIdentifier = productIdentifier;
	return prod;
}
- (NSString *)productIdentifier
{
	return productIdentifier;
}
@end

#pragma mark - Private SSKManager methods

@interface SSKManager()
+ (void)setObject:(id) object forKey:(NSString *)key;
+ (NSString *)objectForKey:(NSString *)key;

- (void)successfullPurchase:(NSString *)productIdentifier;
- (void)canceledPurchase:(NSString *)productIdentifier;
- (void)erroneousPurchase:(NSString *)productIdentifier error:(NSError *)error;

- (void)completePurchase:(NSString *)productIdentifier withReceipt:(NSData *)receipt;

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)enqueuePurchase:(NSString *)productIdentifier;
- (void)rememberPurchaseOfProduct:(NSString *)productIdentifier withReceipt:(NSData *)receipt;
- (SSKProduct *)productForProductIdentifier:(NSString *)productIdentifier;

@property (nonatomic, strong) NSDictionary *consumables;
@property (nonatomic, strong) NSArray *nonConsumables;
@property (nonatomic, strong) NSDictionary *subscriptions;

@property (nonatomic, strong) NSMutableArray *products;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;

@property (nonatomic, copy) completionHandler_t onRestoreComplete;
@property (nonatomic, copy) errorHandler_t onRestoreError;
@end

#pragma mark - Private API of SSKProduct

@interface SSKProduct(Product)
@property (nonatomic, strong) SKProduct *product;
@end

#pragma mark - Constants

NSString *sskErrorDomain = @"sskErrorDomain";

NSString *kProductsFetchedNotification = @"SStoreKitProductsFetched";
NSString *kSubscriptionInvalidNotification = @"SStoreKitSubscriptionInvalid";
NSString *kProductReceiptInvalidNotification = @"SStoreKitProductReceiptInvalid";

#pragma mark - Implementation

@implementation SSKManager

@synthesize consumables, nonConsumables, subscriptions;
@synthesize pendingRequests, products;
@synthesize onRestoreComplete, onRestoreError;
@synthesize uuidForReview;

+ (SSKManager *)sharedManager
{
	static SSKManager *sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[SSKManager alloc] init];
	});
	return sharedManager;
}

- (id)init
{
	if((self = [super init]))
	{
		products = [[NSMutableArray alloc] init];
		pendingRequests = [[NSMutableDictionary alloc] init];
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	}
	return self;
}

- (NSString *)uuidForReview
{
	if(uuidForReview == nil)
	{
		UIDevice *dev = [UIDevice currentDevice];
		if ([dev respondsToSelector:@selector(uniqueIdentifier)])
			uuidForReview = [dev valueForKey:@"uniqueIdentifier"];
		else {
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			id uuid = [defaults objectForKey:@"uniqueID"];
			if (uuid)
				uuidForReview = (NSString *)uuid;
			else
			{
				CFUUIDRef cfUuidRef = CFUUIDCreate(kCFAllocatorDefault);
				CFStringRef cfUuid = CFUUIDCreateString(kCFAllocatorDefault, cfUuidRef);
				uuidForReview = [(__bridge NSString *)cfUuid copy];
				CFRelease(cfUuid);
				CFRelease(cfUuidRef);
				[defaults setObject:uuidForReview forKey:@"uniqueID"];
			}
		}
	}
	return uuidForReview;
}

- (NSArray *)purchasables
{
	return products;
}

#pragma mark - Keychain

+ (void)deleteObjectForKey:(NSString *)key
{
	NSError *error = nil;
	[SFHFKeychainUtils deleteItemForUsername:key
							  andServiceName:KEYCHAIN_SERVICE
									   error:&error];

	if(error)
		NSLog(@"%@", [error localizedDescription]);
}

+ (void)setObject:(id) object forKey:(NSString *)key
{
	NSString *objectString = nil;
	if([object isKindOfClass:[NSData class]])
	{
		objectString = [[NSString alloc] initWithData:object encoding:NSUTF8StringEncoding];
	}
	else if([object respondsToSelector:@selector(stringValue)])
	{
		objectString = [object stringValue];
	}
	else if([object isKindOfClass:[NSString class]])
	{
		objectString = object;
	}
	else
	{
		[NSException raise:@"ExcUnknownObjectType" format:@"[SSKManager setObject:forKey:] object for key %@ has invalid type: %@", key, object];
	}

	NSError *error = nil;
	[SFHFKeychainUtils storeUsername:key
						 andPassword:objectString
					  forServiceName:KEYCHAIN_SERVICE
					  updateExisting:YES
							   error:&error];

	if(error)
		NSLog(@"%@", [error localizedDescription]);
}

+ (NSString *)objectForKey:(NSString *)key
{
	NSError *error = nil;
	NSString *object = [SFHFKeychainUtils getPasswordForUsername:key
												  andServiceName:KEYCHAIN_SERVICE
														   error:&error];
	if(error)
		NSLog(@"%@", [error localizedDescription]);

	return object;
}

+ (NSNumber *)numberForKey:(NSString *)key
{
	return [NSNumber numberWithInteger:[[self objectForKey:key] integerValue]];
}

+ (NSData *)dataForKey:(NSString *)key
{
	NSString *str = [self objectForKey:key];
	return [str dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)removeAllKeychainData
{
	NSMutableArray *productsArray = [NSMutableArray array];
	[productsArray addObjectsFromArray:[consumables allKeys]];
	[productsArray addObjectsFromArray:nonConsumables];
	[productsArray addObjectsFromArray:[subscriptions allKeys]];

	NSError *error = nil;
	for(NSString *productIdentifier in productsArray)
	{
		[SFHFKeychainUtils deleteItemForUsername:productIdentifier
								  andServiceName:KEYCHAIN_SERVICE
										   error:&error];
		[SFHFKeychainUtils deleteItemForUsername:[NSString stringWithFormat:@"%@+Code", productIdentifier]
								  andServiceName:KEYCHAIN_SERVICE
										   error:nil]; // ignore errors for this one
	}
	return error == nil;
}

#pragma mark - External API

- (void)lookForProducts:(NSDictionary *)storeKitItems
{
	[products removeAllObjects];
	[pendingRequests removeAllObjects];

	NSMutableArray *productsArray = [NSMutableArray array];
	self.consumables = [storeKitItems objectForKey:@"Consumables"];
	self.nonConsumables = [storeKitItems objectForKey:@"Non-Consumables"];
	self.subscriptions = [storeKitItems objectForKey:@"Subscriptions"];

	[productsArray addObjectsFromArray:[consumables allKeys]];
	[productsArray addObjectsFromArray:nonConsumables];
	[productsArray addObjectsFromArray:[subscriptions allKeys]];

	SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productsArray]];
	request.delegate = self;
	[request start];
}

- (void)portFromMKStoreKit
{
	for(SSKProduct *product in self.products)
	{
		NSString *key = product.productIdentifier;
		NSError *error = nil;
		NSString *object = [SFHFKeychainUtils getPasswordForUsername:key
													  andServiceName:@"MKStoreKit"
															   error:&error];
		if(!error && object && ![object isEqualToString:@""])
		{
			[SSKManager setObject:object forKey:key];
			// TODO: remove old entries at some point in the future
		}
	}
}

+ (BOOL)isFeaturePurchased:(NSString *)productIdentifier
{
	return [self objectForKey:productIdentifier] != nil;
}

- (void)verifyProducts
{
	for(SSKProduct *product in self.products)
	{
		NSString *productIdentifier = product.productIdentifier;
		NSData *receipt = [SSKManager dataForKey:productIdentifier];

		productCompletionHandler_t cHandler = ^(BOOL success)
		{
			// failed to verify purchase or review privileges, revoke purchase
			if(!success)
			{
				[SSKManager deleteObjectForKey:productIdentifier];
				[[NSNotificationCenter defaultCenter] postNotificationName:kProductReceiptInvalidNotification
																	object:productIdentifier
																  userInfo:nil];
			}
		};
		productErrorHandler_t eHandler = ^(NSError *error){ /* ignore */ };

		if(receipt)
		{
#if defined(REVIEW_ALLOWED)
			if(REVIEW_ALLOWED && [receipt isEqualToData:[@"REVIEW ACCESS" dataUsingEncoding:NSUTF8StringEncoding]])
				[product reviewRequestCompletionHandler:cHandler
										   errorHandler:eHandler];
			else
#endif
#if defined(OWN_SERVER)
			if([receipt isEqualToData:[@"CODE REDEEMED" dataUsingEncoding:NSUTF8StringEncoding]])
				[product redeemCode:[SSKManager objectForKey:[NSString stringWithFormat:@"%@+Code", productIdentifier]]
						 onComplete:cHandler
					   errorHandler:eHandler];
			else
#endif
			[product verifyReceipt:receipt
						onComplete:cHandler
					  errorHandler:eHandler];
		}
	}
}

- (void)redeemCode:(NSString *)code forProduct:(SSKProduct *)product completionHandler:(completionHandler_t)completionHandler errorHandler:(errorHandler_t)errorHandler
{
	NSString *productIdentifier = product.productIdentifier;
	completionHandler_t cHandler = [completionHandler copy];
	errorHandler_t eHandler = [errorHandler copy];

	dispatch_async(dispatch_get_main_queue(), ^{
		[product redeemCode:code
				 onComplete:^(BOOL success)
		 {
			 if(success)
			 {
				 [self rememberPurchaseOfProduct:productIdentifier withReceipt:[@"CODE REEEMED" dataUsingEncoding:NSUTF8StringEncoding]];
				 [SSKManager setObject:code forKey:[NSString stringWithFormat:@"%@+Code", productIdentifier]];
				 cHandler(productIdentifier);
			 }
			 else
			 {
				 NSError *error = [NSError errorWithDomain:sskErrorDomain
													  code:103
												  userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Failed to redeem code: already used?.", @"") forKey:NSLocalizedFailureReasonErrorKey]];
				 eHandler(productIdentifier, error);
			 }
		 }
			   errorHandler:^(NSError *error)
		 {
			 eHandler(productIdentifier, error);
		 }];
	});
}

- (void)redeemCode:(NSString *)code forProductIdentifier:(NSString *)productIdentifier completionHandler:(completionHandler_t)completionHandler errorHandler:(errorHandler_t)errorHandler
{
	SSKProduct *product = [SSKBlindProduct productWithIdentifier:productIdentifier];
	[self redeemCode:code
		  forProduct:product completionHandler:completionHandler
		errorHandler:errorHandler];
}

- (void)buyProduct:(SSKProduct *)product completionHandler:(completionHandler_t)completionHandler cancelHandler:(cancelHandler_t)cancelHandler errorHandler:(errorHandler_t)errorHandler
{
	NSString *productIdentifier = product.productIdentifier;
	// only allow one pending request and keep track of callbacks in associative array
	@synchronized(self)
	{
		if([pendingRequests objectForKey:productIdentifier] != nil)
		{
			errorHandler(productIdentifier, [NSError errorWithDomain:sskErrorDomain
																code:100
															userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"There already is a pending request for this product.", @"") forKey:NSLocalizedFailureReasonErrorKey]]);
			return;
		}
		[pendingRequests setObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[completionHandler copy], @"completionHandler",
									[cancelHandler copy], @"cancelHandler",
									[errorHandler copy], @"errorHandler",
									nil]
							forKey:productIdentifier];
	}

#if defined(REVIEW_ALLOWED)
	dispatch_async(dispatch_get_main_queue(), ^{
		[product reviewRequestCompletionHandler:^(BOOL success)
		{
			if(success)
			{
				[self showAlertWithTitle:NSLocalizedString(@"Review request approved", @"")
								 message:NSLocalizedString(@"You can use this feature for reviewing the app.", @"")];
				[self rememberPurchaseOfProduct:productIdentifier withReceipt:[@"REVIEW ACCESS" dataUsingEncoding:NSUTF8StringEncoding]];
				[self successfullPurchase:productIdentifier];
			}
			else
				[self enqueuePurchase:productIdentifier];
		}
								   errorHandler:^(NSError *error)
		{
			[self enqueuePurchase:productIdentifier];
		}];
	});
#else
	[self enqueuePurchase:productIdentifier];
#endif
}

- (void)restorePreviousPurchasesOnComplete:(completionHandler_t)completionHandler onError:(errorHandler_t)errorHandler
{
	self.onRestoreComplete = completionHandler;
	self.onRestoreError = errorHandler;
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - Interal API

- (void)successfullPurchase:(NSString *)productIdentifier
{
	completionHandler_t handler = [[pendingRequests objectForKey:productIdentifier] objectForKey:@"completionHandler"];
	if(handler)
		handler(productIdentifier);
	[pendingRequests removeObjectForKey:productIdentifier];
}

- (void)canceledPurchase:(NSString *)productIdentifier
{
	cancelHandler_t handler = [[pendingRequests objectForKey:productIdentifier] objectForKey:@"cancelHandler"];
	if(handler)
		handler(productIdentifier);
	[pendingRequests removeObjectForKey:productIdentifier];
}

- (void)erroneousPurchase:(NSString *)productIdentifier error:(NSError *)error
{
	errorHandler_t handler = [[pendingRequests objectForKey:productIdentifier] objectForKey:@"errorHandler"];
	if(handler)
		handler(productIdentifier, error);
	[pendingRequests removeObjectForKey:productIdentifier];
}

- (void)completePurchase:(NSString *)productIdentifier withReceipt:(NSData *)receipt
{
	SSKProduct *product = [self productForProductIdentifier:productIdentifier];
	if(!product)
	{
		NSLog(@"Failed to obtain product for product identifier %@.", productIdentifier);
		product = [[SSKProduct alloc] init];
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[product verifyReceipt:receipt
					onComplete:^(BOOL success)
		{
			if(success)
			{
				[self rememberPurchaseOfProduct:productIdentifier withReceipt:receipt];
				[self successfullPurchase:productIdentifier];
			}
			else
			{
				NSError *error = [NSError errorWithDomain:sskErrorDomain
													 code:101
												 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Verification of purchase receipt failed.", @"") forKey:NSLocalizedFailureReasonErrorKey]];
				[self erroneousPurchase:productIdentifier error:error];
			}
		}
				  errorHandler:^(NSError *error)
		{
			// NOTE: how to properly handle this?
			[self erroneousPurchase:productIdentifier error:error];
		}];
	});
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
													message:message
												   delegate:nil
										  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
										  otherButtonTitles:nil];
	[alert show];
}

- (void)enqueuePurchase:(NSString *)productIdentifier
{
	if ([SKPaymentQueue canMakePayments])
	{
		SSKProduct *product = [self productForProductIdentifier:productIdentifier];
		if(!product)
		{
			NSError *error = [NSError errorWithDomain:sskErrorDomain
												 code:102
											 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Unable to find product for the given product identifier.", @"") forKey:NSLocalizedFailureReasonErrorKey]];
			return [self erroneousPurchase:productIdentifier error:error];
		}

		SKProduct *thisProduct = product.product;
		SKPayment *payment = [SKPayment paymentWithProduct:thisProduct];
		dispatch_async(dispatch_get_main_queue(), ^{
			[[SKPaymentQueue defaultQueue] addPayment:payment];
		});
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"In-App Purchasing disabled", @"")
														message:NSLocalizedString(@"Check your parental control settings and try again later", @"")
													   delegate:self
											  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
											  otherButtonTitles: nil];
		[alert show];
		[self canceledPurchase:productIdentifier];
	}
}

- (void)rememberPurchaseOfProduct:(NSString *)productIdentifier withReceipt:(NSData *)receipt
{
	if([[self.consumables allKeys] containsObject:productIdentifier])
	{
		// TODO: add a way to confirm receipts for consumables at a later point?
		NSDictionary *thisConsumableDict = [self.consumables objectForKey:productIdentifier];
		NSInteger quantityPurchased = [[thisConsumableDict objectForKey:@"Count"] integerValue];
		NSString* productPurchased = [thisConsumableDict objectForKey:@"Name"];

		NSInteger oldCount = [[SSKManager numberForKey:productPurchased] integerValue];
		NSInteger newCount = oldCount + quantityPurchased;

		[SSKManager setObject:[NSNumber numberWithInteger:newCount] forKey:productPurchased];
	}
	else
	{
		[SSKManager setObject:receipt forKey:productIdentifier];
	}
}

- (SSKProduct *)productForProductIdentifier:(NSString *)productIdentifier
{
	for(SSKProduct *product in self.products)
	{
		if([product.productIdentifier isEqualToString:productIdentifier])
			return product;
	}
	return nil;
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	for(SKProduct *product in response.products)
	{
		NSString *subscriptionDays = [self.subscriptions objectForKey:product.productIdentifier];
		if(subscriptionDays)
		{
			SSKProduct *prod = [SSKProduct subscriptionWithProduct:product validForDays:[subscriptionDays integerValue]];
			[self.products addObject:prod];

			// verify if we have an active purchase
			NSString *productIdentifier = product.productIdentifier;
			NSData *receipt = [SSKManager dataForKey:productIdentifier];
			if(receipt)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					[prod verifyReceipt:receipt
								   onComplete:^(BOOL success){
									   if(success)
									   {
										   NSLog(@"Subscription %@ is active", productIdentifier);
									   }
									   else
									   {
										   [[NSNotificationCenter defaultCenter] postNotificationName:kSubscriptionInvalidNotification
																							   object:productIdentifier
																							 userInfo:nil];
										   NSLog(@"Subscription %@ is inactive", productIdentifier);
										   // TODO: delete receipt?
									   }
								   }
								 errorHandler:^(NSError *error){
									 NSLog(@"Unable to verify receipt %@ for product %@.", receipt, productIdentifier);
								 }];
				});
			}
		}
		else
			[self.products addObject:[SSKProduct withProduct:product]];
#ifndef NDEBUG
		NSLog(@"Feature: %@, Cost: %f, ID: %@", [product localizedTitle], [[product price] doubleValue], [product productIdentifier]);
#endif
	}

#ifndef NDEBUG
	for(NSString *invalidProduct in response.invalidProductIdentifiers)
		NSLog(@"Problem in iTunes connect configuration for product: %@", invalidProduct);
#endif

	[[NSNotificationCenter defaultCenter] postNotificationName:kProductFetchedNotification
														object:[NSNumber numberWithBool:YES]
													  userInfo:nil];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kProductFetchedNotification
														object:[NSNumber numberWithBool:NO]
													  userInfo:nil];
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	for (SKPaymentTransaction *transaction in transactions)
	{
		switch (transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
				[self completePurchase:transaction.payment.productIdentifier withReceipt:transaction.transactionReceipt];
				[queue finishTransaction:transaction];
				break;
			case SKPaymentTransactionStateFailed:
				if(transaction.error.code == SKErrorPaymentCancelled)
					[self canceledPurchase:transaction.payment.productIdentifier];
				else
					[self erroneousPurchase:transaction.payment.productIdentifier error:transaction.error];
				[queue finishTransaction:transaction];
				break;
			case SKPaymentTransactionStateRestored:
				[self completePurchase:transaction.originalTransaction.payment.productIdentifier withReceipt:transaction.transactionReceipt];
				[queue finishTransaction:transaction];
				break;
			default:
				break;
		}
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	if(onRestoreError)
		onRestoreError(nil, error);
	self.onRestoreComplete = nil;
	self.onRestoreError = nil;
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	if(onRestoreComplete)
		onRestoreComplete(nil);
	self.onRestoreComplete = nil;
	self.onRestoreError = nil;
}

@end
