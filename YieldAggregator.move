module YieldAggregator::Aggregator {
    use 0x1::Signer;
    use 0x1::Coin;
    use 0x1::Account;
    use 0x1::LendingProtocol;
    use 0x1::YieldProtocol;

    /// Represents the Yield Aggregator object.
    public struct Aggregator has key {
        admin: address,                    // Address of the admin.
        total_deposits: u64,               // Total amount of deposits.
        allocations: vector<Allocation>,   // List of allocations to various protocols.
    }

    /// Represents an allocation to a specific yield protocol.
    public struct Allocation has store {
        protocol: address,                 // Address of the protocol.
        amount: u64,                       // Amount allocated to the protocol.
        yield_rate: u64,                   // Yield rate provided by the protocol.
    }

    /// Initializes the aggregator with the given admin address.
    /// - Parameters:
    ///   - `admin`: The signer representing the admin.
    public fun initialize(admin: &signer) {
        let admin_address = Signer::address_of(admin);
        move_to(admin, Aggregator {
            admin: admin_address,
            total_deposits: 0,
            allocations: vector::empty<Allocation>(),
        });
    }

    /// Allows users to deposit funds into the aggregator.
    /// - Parameters:
    ///   - `user`: The signer representing the user.
    ///   - `amount`: The amount to be deposited.
    public fun deposit(user: &signer, amount: u64) {
        let user_address = Signer::address_of(user);
        let aggregator = borrow_global_mut<Aggregator>(user_address);
        Coin::transfer(user, &aggregator.admin, amount);
        aggregator.total_deposits += amount;
        Self::allocate_funds(aggregator);
    }

    /// Allocates the total deposited funds to the best yield protocol.
    /// - Parameters:
    ///   - `aggregator`: Mutable reference to the aggregator.
    public fun allocate_funds(aggregator: &mut Aggregator) {
        let best_protocol = YieldProtocol::find_best_protocol();
        let allocation = Allocation {
            protocol: best_protocol,
            amount: aggregator.total_deposits,
            yield_rate: YieldProtocol::get_yield_rate(best_protocol),
        };
        vector::push_back(&mut aggregator.allocations, allocation);
        LendingProtocol::deposit(best_protocol, aggregator.total_deposits);
    }

    /// Allows users to withdraw their funds from the aggregator.
    /// - Parameters:
    ///   - `user`: The signer representing the user.
    ///   - `amount`: The amount to be withdrawn.
    public fun withdraw(user: &signer, amount: u64) {
        let user_address = Signer::address_of(user);
        let aggregator = borrow_global_mut<Aggregator>(user_address);
        assert!(aggregator.total_deposits >= amount, 1);
        aggregator.total_deposits -= amount;
        let best_protocol = aggregator.allocations[0].protocol;
        LendingProtocol::withdraw(best_protocol, amount);
        Coin::transfer(&aggregator.admin, user, amount);
        Self::allocate_funds(aggregator);
    }

    /// Provides a view of the current allocations.
    /// - Returns: A vector of `Allocation` structs.
    public fun get_allocation() view returns (vector<Allocation>) {
        let aggregator = borrow_global<Aggregator>(Aggregator::admin);
        aggregator.allocations
    }
}
