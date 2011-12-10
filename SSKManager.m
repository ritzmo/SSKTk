//
//  SSKManager.m
//  dreaMote
//
//  Created by Moritz Venn on 09.12.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import "SSKManager.h"

#import "SFHFKeychainUtils.h"

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

@property (nonatomic, strong) NSDictionary *consumables;
@property (nonatomic, strong) NSArray *nonConsumables;
@property (nonatomic, strong) NSDictionary *subscriptions;

@property (nonatomic, strong) NSMutableArray *products;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;

@property (nonatomic, copy) completionHandler_t onRestoreComplete;
@property (nonatomic, copy) errorHandler_t onRestoreError;
@end

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

+ (void)setObject:(id) object forKey:(NSString *)key
{
	NSString *objectString = nil;
	if([object isKindOfClass:[NSData class]])
	{
		objectString = [[NSString alloc] initWithData:object encoding:NSUTF8StringEncoding];
	}
	if([object isKindOfClass:[NSNumber class]])
	{
		objectString = [(NSNumber*)object stringValue];
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
	return [NSNumber numberWithInt:[[self objectForKey:key] intValue]];
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
        [SFHFKeychainUtils deleteItemForUsername:productIdentifier andServiceName:KEYCHAIN_SERVICE error:&error];
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

	SKProductsRequest *request= [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productsArray]];
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

- (void)buyProduct:(SSKProduct *)product completionHandler:(completionHandler_t)completionHandler cancelHandler:(cancelHandler_t)cancelHandler errorHandler:(errorHandler_t)errorHandler
{
	NSString *productIdentifier = product.productIdentifier;
	// only allow one pending request and keep track of callbacks in associative array
	@synchronized(self)
	{
		if([pendingRequests objectForKey:productIdentifier] != nil)
		{
			errorHandler(productIdentifier, [NSError errorWithDomain:nil code:-1 userInfo:nil]); // TODO: improve
			return;
		}
		[pendingRequests setObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[completionHandler copy], @"completionHandler",
									[cancelHandler copy], @"cancelHandler",
									[errorHandler copy], @"errorHandler",
									nil] forKey:productIdentifier];
	}

#if defined(REVIEW_ALLOWED)
	dispatch_async(dispatch_get_main_queue(), ^{
		[product reviewRequestCompletionHandler:^(BOOL success){
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
								   errorHandler:^(NSError *error){
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
	// TODO: handle subscriptions
	dispatch_async(dispatch_get_main_queue(), ^{
		[SSKProduct verifyReceipt:receipt
					   onComplete:^(BOOL success){
						   if(success)
						   {
							   [self rememberPurchaseOfProduct:productIdentifier withReceipt:receipt];
							   [self successfullPurchase:productIdentifier];
						   }
						   else
						   {
							   NSError *error = [NSError errorWithDomain:nil code:-1 userInfo:nil]; // TODO: improve
							   [self erroneousPurchase:productIdentifier error:error];
						   }
					   }
					 errorHandler:^(NSError *error){
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
        NSArray *allIds = [self.products valueForKey:@"productIdentifier"];
        NSUInteger index = [allIds indexOfObject:productIdentifier];

        if(index == NSNotFound)
		{
			NSError *error = [NSError errorWithDomain:nil code:-1 userInfo:nil]; // TODO: improve
			return [self erroneousPurchase:productIdentifier error:error];
		}

        SKProduct *thisProduct = [self.products objectAtIndex:index];
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

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	for(SKProduct *product in response.products)
	{
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
														object:[NSNumber numberWithBool:YES]];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kProductFetchedNotification
														object:[NSNumber numberWithBool:NO]];
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
