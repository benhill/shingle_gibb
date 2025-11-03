@isTest
private class CustomerOrderTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        // Create test users with different P21_Sales_Rep_ID__c patterns
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String timestamp = String.valueOf(System.now().getTime());

        // User with single salesperson ID
        User user1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser1' + timestamp + '@example.com',
            Username = 'testuser1' + timestamp + '@example.com.test',
            Alias = 'tus1',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '1111',
            IsActive = true
        );

        // User with multiple semicolon-separated salesperson IDs
        User user2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2' + timestamp + '@example.com',
            Username = 'testuser2' + timestamp + '@example.com.test',
            Alias = 'tus2',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '2222;3333;4444',
            IsActive = true
        );

        // User with semicolon-separated IDs with spaces
        User user3 = new User(
            FirstName = 'Test',
            LastName = 'User3',
            Email = 'testuser3' + timestamp + '@example.com',
            Username = 'testuser3' + timestamp + '@example.com.test',
            Alias = 'tus3',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '5555 ; 6666 ; 7777',
            IsActive = true
        );

        // Inactive user (should not be matched)
        User user4 = new User(
            FirstName = 'Test',
            LastName = 'User4',
            Email = 'testuser4' + timestamp + '@example.com',
            Username = 'testuser4' + timestamp + '@example.com.test',
            Alias = 'tus4',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            P21_Sales_Rep_ID__c = '9999',
            IsActive = false
        );

        insert new List<User>{ user1, user2, user3, user4 };

        // Create test accounts with different DUET__salespersonid__c values
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Test Account 1111', DUET__salespersonid__c = '1111'),
            new Account(Name = 'Test Account 2222', DUET__salespersonid__c = '2222'),
            new Account(Name = 'Test Account 3333', DUET__salespersonid__c = '3333'),
            new Account(Name = 'Test Account 4444', DUET__salespersonid__c = '4444'),
            new Account(Name = 'Test Account 6666', DUET__salespersonid__c = '6666'),
            new Account(Name = 'Test Account 8888', DUET__salespersonid__c = '8888'),
            new Account(Name = 'Test Account 9999', DUET__salespersonid__c = '9999'),
            new Account(Name = 'Test Account Blank', DUET__salespersonid__c = null)
        };
        insert accounts;
    }

    @isTest
    static void testSingleSalesPersonIdMatch() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '1111' LIMIT 1];

        Test.startTest();
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount.Id
        );
        insert order;
        Test.stopTest();

        order = [SELECT Id, Salesperson_ID__c, Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(testUser.Id, order.Sales_Person__c, 'Sales_Person__c should be populated with matching User');
        System.assertEquals('1111', order.Salesperson_ID__c, 'Formula field should pull salesperson ID from Account');
    }

    @isTest
    static void testMultipleSalesPersonIdMatch() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '2222;3333;4444' LIMIT 1];
        Account testAccount2222 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '2222' LIMIT 1];
        Account testAccount3333 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '3333' LIMIT 1];
        Account testAccount4444 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '4444' LIMIT 1];

        Test.startTest();
        // Test matching the first ID in the semicolon-separated list
        DUET__Customer_Order__c order1 = new DUET__Customer_Order__c(
            DUET__account__c = testAccount2222.Id
        );
        insert order1;

        // Test matching the middle ID
        DUET__Customer_Order__c order2 = new DUET__Customer_Order__c(
            DUET__account__c = testAccount3333.Id
        );
        insert order2;

        // Test matching the last ID
        DUET__Customer_Order__c order3 = new DUET__Customer_Order__c(
            DUET__account__c = testAccount4444.Id
        );
        insert order3;
        Test.stopTest();

        order1 = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order1.Id];
        order2 = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order2.Id];
        order3 = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order3.Id];

        System.assertEquals(testUser.Id, order1.Sales_Person__c, 'Should match first ID in semicolon list');
        System.assertEquals(testUser.Id, order2.Sales_Person__c, 'Should match middle ID in semicolon list');
        System.assertEquals(testUser.Id, order3.Sales_Person__c, 'Should match last ID in semicolon list');
    }

    @isTest
    static void testSalesPersonIdWithSpaces() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '5555 ; 6666 ; 7777' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '6666' LIMIT 1];

        Test.startTest();
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount.Id
        );
        insert order;
        Test.stopTest();

        order = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(testUser.Id, order.Sales_Person__c, 'Should match ID even with spaces in User field');
    }

    @isTest
    static void testNoMatch() {
        Account testAccount = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '8888' LIMIT 1];

        Test.startTest();
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount.Id
        );
        insert order;
        Test.stopTest();

        order = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(null, order.Sales_Person__c, 'Sales_Person__c should be null when no match found');
    }

    @isTest
    static void testInactiveUserNotMatched() {
        Account testAccount = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '9999' LIMIT 1];

        Test.startTest();
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount.Id
        );
        insert order;
        Test.stopTest();

        order = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(null, order.Sales_Person__c, 'Inactive users should not be matched');
    }

    @isTest
    static void testBlankSalesPersonId() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account Blank' LIMIT 1];

        Test.startTest();
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount.Id
        );
        insert order;
        Test.stopTest();

        order = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(null, order.Sales_Person__c, 'Sales_Person__c should be null when Salesperson_ID__c is blank');
    }

    @isTest
    static void testUpdateCustomerOrder() {
        User testUser1 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        User testUser2 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '2222;3333;4444' LIMIT 1];
        Account testAccount1 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '1111' LIMIT 1];
        Account testAccount2 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '2222' LIMIT 1];

        // Insert order with first account/sales rep
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount1.Id
        );
        insert order;

        order = [SELECT Salesperson_ID__c, Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(testUser1.Id, order.Sales_Person__c, 'Should initially match first user');

        Test.startTest();
        // Update to second account/sales rep
        order.DUET__account__c = testAccount2.Id;
        update order;
        Test.stopTest();

        order = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(testUser2.Id, order.Sales_Person__c, 'Should update to match second user');
    }

    @isTest
    static void testBulkInsert() {
        User testUser1 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        User testUser2 = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '2222;3333;4444' LIMIT 1];
        Account testAccount1 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '1111' LIMIT 1];
        Account testAccount2 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '2222' LIMIT 1];

        List<DUET__Customer_Order__c> orders = new List<DUET__Customer_Order__c>();

        // Create 200 orders to test bulk processing
        for (Integer i = 0; i < 100; i++) {
            orders.add(new DUET__Customer_Order__c(DUET__account__c = testAccount1.Id));
            orders.add(new DUET__Customer_Order__c(DUET__account__c = testAccount2.Id));
        }

        Test.startTest();
        insert orders;
        Test.stopTest();

        List<DUET__Customer_Order__c> insertedOrders = [
            SELECT Salesperson_ID__c, Sales_Person__c
            FROM DUET__Customer_Order__c
            WHERE Id IN :orders
            ORDER BY Salesperson_ID__c
        ];

        System.assertEquals(200, insertedOrders.size(), 'Should insert all 200 orders');

        Integer user1Matches = 0;
        Integer user2Matches = 0;

        for (DUET__Customer_Order__c ord : insertedOrders) {
            if (ord.Salesperson_ID__c == '1111') {
                System.assertEquals(testUser1.Id, ord.Sales_Person__c, 'Bulk insert should match user 1');
                user1Matches++;
            } else if (ord.Salesperson_ID__c == '2222') {
                System.assertEquals(testUser2.Id, ord.Sales_Person__c, 'Bulk insert should match user 2');
                user2Matches++;
            }
        }

        System.assertEquals(100, user1Matches, 'Should have 100 orders matched to user 1');
        System.assertEquals(100, user2Matches, 'Should have 100 orders matched to user 2');
    }

    @isTest
    static void testClearLookupOnUpdate() {
        User testUser = [SELECT Id FROM User WHERE P21_Sales_Rep_ID__c = '1111' LIMIT 1];
        Account testAccount1 = [SELECT Id FROM Account WHERE DUET__salespersonid__c = '1111' LIMIT 1];
        Account testAccountBlank = [SELECT Id FROM Account WHERE Name = 'Test Account Blank' LIMIT 1];

        // Insert order with sales rep
        DUET__Customer_Order__c order = new DUET__Customer_Order__c(
            DUET__account__c = testAccount1.Id
        );
        insert order;

        order = [SELECT Salesperson_ID__c, Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(testUser.Id, order.Sales_Person__c, 'Should initially have user populated');

        Test.startTest();
        // Update to account with blank salesperson ID
        order.DUET__account__c = testAccountBlank.Id;
        update order;
        Test.stopTest();

        order = [SELECT Sales_Person__c FROM DUET__Customer_Order__c WHERE Id = :order.Id];
        System.assertEquals(null, order.Sales_Person__c, 'Should clear lookup when Salesperson_ID__c is cleared');
    }
}
