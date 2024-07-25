module YieldAggregator::Aggregator {
    use 0x1::Signer;
    use 0x1::Coin;
    use 0x1::Account;
    use 0x1::LendingProtocol;
    use 0x1::YieldProtocol;

    struct Aggregator {
        admin: address,
        total_deposits: u64,
        allocations: vector<Allocation>,
    }

    struct Allocation {
        protocol: address,
        amount: u64,
        yield_rate: u64,
    }

    public fun initialize(admin: &signer) {
        let admin_address = Signer::address_of(admin);
        move_to(&admin, Aggregator {
            admin: admin_address,
            total_deposits: 0,
            allocations: vector::empty<Allocation>(),
        });
    }

    public fun deposit(user: &signer, amount: u64) {
        let aggregator = borrow_global_mut<Aggregator>(Signer::address_of(user));
        Coin::transfer(user, &aggregator.admin, amount);
        aggregator.total_deposits = aggregator.total_deposits + amount;
        Self::allocate_funds(aggregator);
    }

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

    public fun withdraw(user: &signer, amount: u64) {
        let aggregator = borrow_global_mut<Aggregator>(Signer::address_of(user));
        assert!(aggregator.total_deposits >= amount, 1);
        aggregator.total_deposits = aggregator.total_deposits - amount;
        let best_protocol = aggregator.allocations[0].protocol;
        LendingProtocol::withdraw(best_protocol, amount);
        Coin::transfer(&aggregator.admin, user, amount);
        Self::allocate_funds(aggregator);
    }

    public fun get_allocation() view returns (vector<Allocation>) {
        let aggregator = borrow_global<Aggregator>(Signer::address_of(&Aggregator::admin));
        aggregator.allocations
    }
}
