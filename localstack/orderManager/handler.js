const AWS = require( 'aws-sdk' );
const eventBridge = new AWS.EventBridge({
  region: 'us-east-1',
  endpoint: 'http://localstack:4566',
});

function putEventInEventBridge(orderDetails) {

    const detail = { 
      restaurantName: orderDetails.restaurantName,
      order: orderDetails.order,
      customerName: orderDetails.name,
      amount: orderDetails.amount
    };
  
    var params = {
      Entries: [
        {
          Detail: JSON.stringify(detail),
          DetailType: 'order',
          Source: 'custom.orderManager',
          EventBusName: 'default'
        },
      ]
    };
  
    console.log('PARAMS', params);
    return eventBridge.putEvents(params).promise();
  }

exports.putOrder = async (event) => {
    console.log( '******PUTORDER*******' );
  
    console.log('BODY', event.body)

    const orderDetails = JSON.parse(event.body);
    
    try {
      const data = await putEventInEventBridge(orderDetails);

      console.log('DATA', data);
    
      return {
          statusCode: 200,
          body: JSON.stringify(orderDetails),
          headers: {}
        }
    } catch (error) {
      console.error('Error sending event to EventBridge', error);
      return {
        statusCode: 500,
        body: JSON.stringify({ error: 'Failed to send event to EventBridge' }),
        headers: {}
      }
    }  
}