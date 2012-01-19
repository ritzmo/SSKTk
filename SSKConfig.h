//
//  SSKConfig.h
//  dreaMote
//
//  Created by Moritz Venn on 09.12.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

// TODO: add toggles to remove functionality from binary

#ifndef KEYCHAIN_SERVICE
	#define KEYCHAIN_SERVICE @"SSKToolkit"
#endif

#if !defined(USE_SFHFKEYCHAIN) && !defined(USE_SSKEYCHAIN)
	#define USE_SSKEYCHAIN
#endif

//#define REVIEW_ALLOWED 1

//#define OWN_SERVER @"http://www.myserver.com/mypath"

#ifndef kSharedSecret
	#define kSharedSecret nil
#endif