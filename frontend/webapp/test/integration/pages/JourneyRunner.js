sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"com/portfolio/o2corder/test/integration/pages/OrderHeaderList.gen",
	"com/portfolio/o2corder/test/integration/pages/OrderHeaderObjectPage.gen"
], function (JourneyRunner, OrderHeaderListGenerated, OrderHeaderObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('com/portfolio/o2corder') + '/test/flp.html#app-preview',
        pages: {
			onTheOrderHeaderListGenerated: OrderHeaderListGenerated,
			onTheOrderHeaderObjectPageGenerated: OrderHeaderObjectPageGenerated
        },
        async: true
    });

    return runner;
});

