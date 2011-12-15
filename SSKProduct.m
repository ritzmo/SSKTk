//
//  SSKProduct.m
//  dreaMote
//
//  Created by Moritz Venn on 09.12.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import "SSKProduct.h"

#import "SSKManager.h"

#import "JSONKit.h"
#import "NSData+Base64.h"
#import "NSString+URLEncode.h"

#ifndef NDEBUG
	#define kReceiptValidationURL @"https://sandbox.itunes.apple.com/verifyReceipt"
#else
	#define kReceiptValidationURL @"https://buy.itunes.apple.com/verifyReceipt"
#endif

@interface SSKProduct()
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, copy) productCompletionHandler_t completionHandler;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, copy) productErrorHandler_t errorHandler;
@property (nonatomic, strong) SKProduct *product;
@property (nonatomic, strong) NSDictionary *receipt;
@property (nonatomic) NSInteger subscriptionDays;
@end

@implementation SSKProduct

@synthesize connection, completionHandler, data, errorHandler, product, receipt, subscriptionDays;

+ (SSKProduct *)withProduct:(SKProduct *)product
{
	SSKProduct *prod = [[SSKProduct alloc] init];
	prod.product = product;
	return prod;
}

+ (SSKProduct *)subscriptionWithProduct:(SKProduct *)product validForDays:(NSInteger)days
{
	SSKProduct *prod = [self withProduct:product];
	prod.subscriptionDays = days;
	return prod;
}

- (void)verifyReceipt:(NSData *)receiptData onComplete:(productCompletionHandler_t)cHandler errorHandler:(productErrorHandler_t)eHandler
{
	completionHandler = cHandler;
	errorHandler = eHandler;

#if defined(OWN_SERVER)
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", OWN_SERVER, @"verifyProduct.php"]];
#else
	NSURL *url = [NSURL URLWithString:kReceiptValidationURL];
#endif

	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url
															  cachePolicy:NSURLRequestReloadIgnoringCacheData
														  timeoutInterval:60];

	[theRequest setHTTPMethod:@"POST"];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

	NSString *postData = nil;
#if defined(OWN_SERVER)
	postData = [NSString stringWithFormat:@"receiptdata=%@", [receiptData base64EncodedString]];
#else
	postData = [NSString stringWithFormat:@"{\"receipt-data\":\"%@\", \"password\":\"%@\"}", [receiptData base64EncodedString], kSharedSecret];
#endif

	NSString *length = [NSString stringWithFormat:@"%d", [postData length]];
	[theRequest setValue:length forHTTPHeaderField:@"Content-Length"];

	[theRequest setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];

	connection = [NSURLConnection connectionWithRequest:theRequest delegate:self];
	[connection start];
}

- (void)redeemCode:(NSString *)code onComplete:(productCompletionHandler_t)cHandler errorHandler:(productErrorHandler_t)eHandler
{
#if defined(OWN_SERVER)
	completionHandler = cHandler;
	errorHandler = eHandler;

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", OWN_SERVER, @"redeemCode.php"]];
	NSString *uniqueID = [SSKManager sharedManager].uuidForReview;

	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url
															  cachePolicy:NSURLRequestReloadIgnoringCacheData
														  timeoutInterval:60];

	[theRequest setHTTPMethod:@"POST"];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

	NSString *postData = [NSString stringWithFormat:@"productid=%@&code=%@&uuid=%@", product.productIdentifier, [code urlencode], uniqueID];

	NSString *length = [NSString stringWithFormat:@"%d", [postData length]];
	[theRequest setValue:length forHTTPHeaderField:@"Content-Length"];

	[theRequest setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];

	connection = [NSURLConnection connectionWithRequest:theRequest delegate:self];
	[connection start];
#else
	cHandler(NO);
#endif
}

#if defined(REVIEW_ALLOWED)
- (void)reviewRequestCompletionHandler:(productCompletionHandler_t)cHandler errorHandler:(productErrorHandler_t)eHandler
{
	if(!REVIEW_ALLOWED)
		return completionHandler(NO);
#if defined(OWN_SERVER)
	completionHandler = cHandler;
	errorHandler = eHandler;

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", OWN_SERVER, @"featureCheck.php"]];
	NSString *uniqueID = [SSKManager sharedManager].uuidForReview;

	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url
															  cachePolicy:NSURLRequestReloadIgnoringCacheData
														  timeoutInterval:60];

	[theRequest setHTTPMethod:@"POST"];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

	NSString *postData = [NSString stringWithFormat:@"productid=%@&uuid=%@", product.productIdentifier, uniqueID];

	NSString *length = [NSString stringWithFormat:@"%d", [postData length]];
	[theRequest setValue:length forHTTPHeaderField:@"Content-Length"];

	[theRequest setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];

	connection = [NSURLConnection connectionWithRequest:theRequest delegate:self];
	[connection start];
#else
	cHandler(NO)
#endif
}
#endif

- (NSString *)stringValue
{
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	[numberFormatter setLocale:product.priceLocale];
	NSString *formattedString = [numberFormatter stringFromNumber:product.price];

	NSString *description = [NSString stringWithFormat:@"%@ (%@)", [product localizedTitle], formattedString];

#ifndef NDEBUG
	NSLog(@"Product %@", description);
#endif
	return description;
}

- (NSString *)productIdentifier
{
	return product.productIdentifier;
}

- (BOOL)subscriptionActive
{
	if([self.receipt objectForKey:@"expires_date"])
	{
        NSTimeInterval expiresDate = [[self.receipt objectForKey:@"expires_date"] doubleValue]/1000.0;
        return expiresDate > [[NSDate date] timeIntervalSince1970];
    }
	else
	{
        NSString *purchase_data = [self.receipt objectForKey:@"purchase_date"];
        if(!purchase_data)
		{
            NSLog(@"Receipt is invalid: %@", self.receipt);
            return NO;
        }
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        purchase_data = [purchase_data stringByReplacingOccurrencesOfString:@" Etc/GMT" withString:@""];
        NSLocale *POSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [df setLocale:POSIXLocale];
        [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate *date = [df dateFromString:purchase_data];
        NSInteger numberOfDays = [date timeIntervalSinceNow] / (-86400.0);
        return (subscriptionDays > numberOfDays);
    }
}

#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	data = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)rdata
{
	[data appendData:rdata];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
#if defined(OWN_SERVER)
	// TODO: add some sort of wrapper/encryption
#endif
	NSDictionary *dict = [data objectFromJSONData];
	const NSString *status = [dict objectForKey:@"status"];
	const BOOL isValid = (status && [status integerValue] == 0);
	const NSString *exception = [dict objectForKey:@"exception"];
	if(isValid)
	{
		self.receipt = [dict objectForKey:@"receipt"];
	}
	else if(exception && errorHandler)
	{
		NSError *error = [NSError errorWithDomain:sskErrorDomain
											 code:104
										 userInfo:[NSDictionary dictionaryWithObject:exception forKey:NSLocalizedDescriptionKey]];
		errorHandler(error);
		completionHandler = nil; // abort calling the completion handler too
	}

	if(completionHandler)
		completionHandler(isValid);
	data = nil;
	self.connection = nil;
	self.completionHandler = nil;
	self.errorHandler = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	data = nil;
	if(errorHandler)
		errorHandler(error);
	self.connection = nil;
	self.completionHandler = nil;
	self.errorHandler = nil;
}

@end
