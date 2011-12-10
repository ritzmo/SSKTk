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
@end

@implementation SSKProduct

@synthesize connection, completionHandler, data, errorHandler, product;

+ (SSKProduct *)withProduct:(SKProduct *)product
{
	SSKProduct *prod = [[SSKProduct alloc] init];
	prod.product = product;
	return prod;
}

+ (void)verifyReceipt:(NSData *)receipt onComplete:(productCompletionHandler_t)completionHandler errorHandler:(productErrorHandler_t)errorHandler
{
	SSKProduct *prod = [[SSKProduct alloc] init];
	prod.completionHandler = completionHandler;
	prod.errorHandler = errorHandler;

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
	postData = [NSString stringWithFormat:@"receiptdata=%@", [receipt base64EncodedString]];
#else
	postData = [NSString stringWithFormat:@"{\"receipt-data\":\"%@\" \"password\":\"%@\"}", [receipt base64EncodedString], kSharedSecret];
#endif

	NSString *length = [NSString stringWithFormat:@"%d", [postData length]];
	[theRequest setValue:length forHTTPHeaderField:@"Content-Length"];

	[theRequest setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];

    prod.connection = [NSURLConnection connectionWithRequest:theRequest delegate:self];
    [prod.connection start];
}

- (void)reviewRequestCompletionHandler:(productCompletionHandler_t)cHandler errorHandler:(productErrorHandler_t)eHandler
{
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
	eHandler(nil);
#endif
}

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
	NSString *responseString = [[NSString alloc] initWithData:data
													 encoding:NSASCIIStringEncoding];
	if([responseString isEqualToString:@"YES"])
#else
	NSDictionary *dict = [data objectFromJSONData];
	if([[dict objectForKey:@"status"] integerValue] == 0)
#endif
	{
		if(completionHandler)
			completionHandler(YES);
	}
	else
	{
		if(errorHandler)
			errorHandler(nil);
	}
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
