{{ dbt_utils.union_relations(

    relations=[(
        ref('stg_airbnb_25.09.23__calendar'), 
        ref('stg_airbnb_25.12.27__calendar'), 
        ref('stg_airbnb_26.03.28__calendar'),
        ref('stg_airbnb_26.06.26__calendar')
)]

) }}