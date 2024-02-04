if 'transformer' not in globals():
    from mage_ai.data_preparation.decorators import transformer
if 'test' not in globals():
    from mage_ai.data_preparation.decorators import test


@transformer
def transform(data, *args, **kwargs):


    dtf = data[(data['passenger_count'] > 0) & (data['trip_distance'] > 0)]
    dtf['lpep_pickup_date'] = dtf['lpep_pickup_datetime'].dt.date

    dtf.columns = (dtf.columns
                    .str.replace('(?<=[a-z])(?=[A-Z])', '_', regex=True)
                    .str.lower()
                )

    return dtf


@test
def test_columns(output) -> None:
    assert output.columns[0] == 'vendor_id', 'First column has the name != vendor_id'

@test
def test_passenger_count(output, *args) -> None:
    assert (output['passenger_count'] == 0).sum() == 0, 'There are rows with passenger_count == 0'

@test
def test_trip_distance(output, *args) -> None:
    assert (output['trip_distance'] == 0).sum() == 0, 'There are rows with trip_distance == 0'
