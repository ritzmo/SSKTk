<?php
    /**
     * Verify a receipt and return receipt data
	 *
	 * Taken from http://www.phpriot.com/articles/verifying-app-store-receipts-php-curl
     *
     * @param   string  $receipt    Base-64 encoded data
     * @param   bool    $isSandbox  Optional. True if verifying a test receipt
     * @throws  Exception   If the receipt is invalid or cannot be verified
     * @return  array       Receipt info (including product ID and quantity)
     */
    function getReceiptData($receipt, $isSandbox = false)
    {
        // determine which endpoint to use for verifying the receipt
        if ($isSandbox) {
            $endpoint = 'https://sandbox.itunes.apple.com/verifyReceipt';
        }
        else {
            $endpoint = 'https://buy.itunes.apple.com/verifyReceipt';
        }
 
        // build the post data
        $postData = json_encode(
            array('receipt-data' => $receipt)
        );
 
        // create the cURL request
        $ch = curl_init($endpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
 
        // execute the cURL request and fetch response data
        $response = curl_exec($ch);
        $errno    = curl_errno($ch);
        $errmsg   = curl_error($ch);
        curl_close($ch);
 
        // ensure the request succeeded
        if ($errno != 0) {
            throw new Exception($errmsg, $errno);
        }
 
        // parse the response data
        $data = json_decode($response);
 
        // ensure response data was a valid JSON string
        if (!is_object($data)) {
            throw new Exception('{"status":-1,"exception":"'.str_replace('"', '\'', $response).'"}');
        }
 
		// we assume a status to be set in our response, so do it
		if(!isset($data->status))
			$data->status = -1;

        // ensure the expected data is present
        if ($data->status != 0) {
            throw new Exception(json_encode($data));
        }
 
		// return the response from apple
		return $response;
    }
 
    // fetch the receipt data and sandbox indicator from the post data
    $receipt   = $_POST['receiptdata'];
    if(get_magic_quotes_gpc()){
        $receipt = stripslashes($receipt);
    }
    $isSandbox = (bool)$_POST['sandbox'];
 
    // verify the receipt
    try {
        $info = getReceiptData($receipt, $isSandbox);
    }
    catch (Exception $ex) {
		$info = $ex->getMessage();
    }
	// TODO: add some kind of encryption
	echo($info);
?>
