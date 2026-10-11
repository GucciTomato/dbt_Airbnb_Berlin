{{ dbt_utils.union_relations(

    relations=[
        ref('stg_airbnb_25.09.23__listings'), 
        ref('stg_airbnb_25.12.27__listings'), 
        ref('stg_airbnb_26.03.28__listings'),
        ref('stg_airbnb_26.06.26__listings')
    ]

) }}