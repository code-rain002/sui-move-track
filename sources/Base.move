
/// Base module for sui
module suitrack::base {
    // use Sui::Coin::{Self, Coin};
    use sui::transfer;
    use std::vector;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    // Error codes
    /// Invalid admin
    const ServiceNotOwner: u64 = 0;
    /// Invalid tracker owner
    const TrackerNotOwner: u64 = 1;
    /// Does not contain value
    const DoesNotExist: u64 = 2;
    /// Wrong value removed
    const ValueDropMismatch: u64 = 3;

    /// Master service setup at deploytime
    struct Service has key {
        id: UID,
        admin: address,
    }

    /// Validate that the address provided is the
    /// owner of the program
    fun is_owner(self: &Service, owner:address): bool {
        self.admin == owner
    }

    /// Master service tracker
    struct ServiceTracker has key {
        id: UID,
        initialized: bool,
        count_accounts: u64,
    }


    /// Bump number of accounts created
    fun increase_account(self: &mut ServiceTracker) {
        self.count_accounts = self.count_accounts + 1;
    }

    /// Return the number of accounts created
    public fun accounts_created(self: &ServiceTracker) : u64 {
        self.count_accounts
    }

    /// Individual account trackers
    struct Tracker has key, store  {
        id: UID,
        initialized: bool,
        accumulator: vector<u8>,
    }

    public fun transfer(tracker: Tracker, recipient: address) {
        // set_tracker_owner(tracker,recipient);
        transfer::transfer<Tracker>(tracker, recipient)
    }

    /// Get the accumulator length
    public fun stored_count(self: &Tracker) : u64 {
        vector::length<u8>(&self.accumulator)
    }

    /// Add an element to the accumulator
    public fun add_to_store(self: &mut Tracker, value: u8) : u64 {
        vector::push_back<u8>(&mut self.accumulator, value);
        stored_count(self)
    }

    /// Add a series of vaues to the accumulator
    public fun add_from(self: &mut Tracker, other:vector<u8>) {
        vector::append<u8>(&mut self.accumulator, other);
    }

    /// Check accumulator contains value
    public fun has_value(self: &Tracker, value: u8) : bool {
        vector::contains<u8>(&self.accumulator, &value)
    }

    /// Removes a value from the accumulator
    public fun drop_from_store(self: &mut Tracker, value: u8) : u8 {
        let (contained, idx) = vector::index_of<u8>(&self.accumulator, &value);
        assert!(contained, DoesNotExist);
        vector::remove<u8>(&mut self.accumulator, idx)
    }

    public fun create_service(ctx: &mut TxContext) {
        // Establish authority and make it immutable
        let sender = tx_context::sender(ctx);
        let id = object::new(ctx);
        transfer::freeze_object(Service {
            id,
            admin: sender,
        })
    }
    /// Create the service tracker for the owner/publisher of this contract
    public fun create_service_tracker(ctx: &mut TxContext) {
        let recipient = tx_context::sender(ctx);
        // Authority tracker
        transfer::transfer(
            ServiceTracker {
                id: object::new(ctx),
                initialized: true,
                count_accounts: 0,
            },
            recipient
        )
    }
    // Transaction Entry Points
    /// Initialize new deployment
    fun init(ctx: &mut TxContext) {
        create_service(ctx);
        create_service_tracker(ctx)
    }


    // Entrypoint: Initialize user account
    public entry fun create_account(
        //use Std::Debug;
        service: &Service,
        strack: &mut ServiceTracker,
        recipient: address,
        ctx: &mut TxContext
        ) {
        // Verify ownership
        let admin = tx_context::sender(ctx);
        assert!(is_owner(service, admin), ServiceNotOwner);

        // Increase the account count
        increase_account(strack);

        // Create unique account tracker for reeipient
        transfer::transfer(
            Tracker {
                id: object::new(ctx),
                initialized: true,
                accumulator: vector[],
            },
            recipient
        );
    }

    /// Add single value to accumulator
    public entry fun add_value(tracker: &mut Tracker, value: u8, _ctx: &mut TxContext) {
        // Verify ownership
        add_to_store(tracker,value);
    }

    /// Add single value to accumulator
    public entry fun remove_value(tracker: &mut Tracker, value: u8, _ctx: &mut TxContext) {
        // Verify ownership
        assert!(drop_from_store(tracker, value) == value,ValueDropMismatch);

    }
    /// Add multiple values to accumulator
    public entry fun add_values(tracker: &mut Tracker, values: vector<u8>, _ctx: &mut TxContext) {
        add_from(tracker, values);
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        create_service(ctx);
        create_service_tracker(ctx)
    }

}