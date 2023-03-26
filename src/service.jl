function add_dataset(id, filename, type)
    ds = DataSet(id=id, filename=filename, type=type)
    
    create_dataset(ds)
end