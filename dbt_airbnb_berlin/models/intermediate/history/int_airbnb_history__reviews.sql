{{ dbt_utils.union_relations(

    relations=[(
        ref('stg_airbnb_25.09.23__reviews'), 
        ref('stg_airbnb_25.12.27__reviews'), 
        ref('stg_airbnb_26.03.28__reviews'),
        ref('stg_airbnb_26.06.26__reviews')
)]

) }}