using SegyIO, LinearAlgebra, HDF5

# Load your 3D RTM image (e.g. as HDF5, MAT, JLD)
x = h5open("/data/pwitte3/azure_results/overthrust_rtm.hdf5", "r") do file
    read(file, "x")
end

## TO DO: set correct sampling interval in z-direction
dz = Int(round(12.5f0 * 1000f0))

# First dimension must be depth (!). If not, flip dimensions to make depth the first dimension.
nz, nx, ny = size(x)
numTraces = prod([nx, ny])

# Create coordinates: simply use trace numbers as coordinates
cdpx = zeros(Float32, numTraces)
cdpy = zeros(Float32, numTraces)
count = 1
xcoords = range(1, stop=nx, length=nx)
ycoords = range(1, stop=ny, length=ny)

for j=1:nx
    for k=1:ny
        cdpx[count] = xcoords[j]
        cdpy[count] = ycoords[k]
        global count += 1
    end
end

cdpx = convert(Array{Int32, 1}, cdpx)
cdpy = convert(Array{Int32, 1}, cdpy)

block = SeisBlock(reshape(x, nz, numTraces));
set_header!(block, "dt", dz)
set_header!(block, "CDPX", cdpx)
set_header!(block, "CDPY", cdpy)
segy_write("rtm_example.segy", block)
