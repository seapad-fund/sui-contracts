#[test_only]
module seapad::launchpad_tests {

    use sui::test_scenario;
    use seapad::project;

    #[test]
    fun test_create_project(){
        let owner = @COFFEE;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            project::init_for_testing(test_scenario::ctx(scenario));
        }
    }

    #[test]
    fun test_update_project(){

    }

    #[test]
    fun test_fundraising_project(){

    }

    #[test]
    fun test_refund_project(){

    }

    #[test]
    fun test_claim_project(){

    }
}

