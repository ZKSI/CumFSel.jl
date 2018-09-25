#!/usr/bin/env julia

using JLD2
using FileIO
using ArgParse
using Distributions
addprocs(8)
@everywhere using Cumulants
@everywhere using CumulantsFeatures
using SymmetricTensors
using StatsBase
using ROCAnalysis


function detection_hosvd(data::Dict, β::Float64, r::Int = 3)
  ret = 0.
  l = length(data["data"])
  de = zeros(l, 2)
  for m=1:l
    println(m)
    d = hosvdc4detect(data["data"]["$m"]["x_malf"], β, r)
    aa = data["a"]
    detected = count(find(d) .<= aa)
    falsep = count(find(d) .> aa)
    de[m,:] = [detected/aa, falsep/(detected+falsep)]
  end
  de
end

function detection_rx(data::Dict, α::Float64 = 0.99)
  ret = 0.
  l = length(data["data"])
  de = zeros(l, 2)
  for m=1:l
    println(m)
    d = find(rxdetect(data["data"]["$m"]["x_malf"], α))
    aa = data["a"]
    detected = count(d .<= aa)
    falsep = count(d .> aa)
    de[m,:] = [detected/aa, falsep/(detected+falsep)]
  end
  de
end

ν = 5
str = "tstudent_$ν-t_size-50_malfsize-10-t_100000_1000.jld2"

data = load(str)
ks = vcat(collect(6.:-0.15:1.2))
roc = [detection_hosvd(data, k) for k in ks]
save("roc"*str, "roc", roc, "ks", ks)

ν = 25
str1 = "tstudent_$ν-t_size-50_malfsize-10-t_100000_1000.jld2"
data1 = load(str1)
roc1 = [detection_hosvd(data1, k) for k in ks]
save("roc"*str1, "roc", roc1, "ks", ks)


data = load(str)
as = vcat(collect(0.45:0.03:0.99), collect(0.991:0.001:0.999), [0.99925, 0.9995, 0.99975, 0.9999, 0.999925, 0.99995, 0.999975, 0.99999, 0.999999, 0.9999999])
as = as[end:-1:1]
rocrx = [detection_rx(data, k) for k in as]
save("rocrx"*str, "roc", rocrx, "alpha", as)

using PyCall
using PyPlot
@pyimport matplotlib as mpl
@pyimport matplotlib.colors as mc
mpl.rc("text", usetex=true)
mpl.use("Agg")

function plotdet(r, rx, j::Int = 3, nu::Int = 5)
  mpl.rc("font", family="serif", size = 7)
  fig, ax = subplots(figsize = (2.5, 2.))
  ret = zeros(size(r[1],1))
  retrx = copy(ret)
  a = ["x-", "d-"]
  for i in 1:size(r[1],1)
    x = [k[i,2] for k in r]
    y = [k[i,1] for k in r]
    xr = [k[i,2] for k in rx]
    yr = [k[i,1] for k in rx]
    ret[i] = auc(x,y)
    retrx[i] = auc(xr,yr)
    if i == j
      p = sortperm(x)
      p1 = sortperm(xr)
      x = x[p]
      y = y[p]
      xr = xr[p1]
      yr = yr[p1]
      plt[:semilogx](x, y, "--", label = "Alg. 1", color = "blue")
      plt[:semilogx](xr, yr, "--", label = "RX", color = "red")
      ax[:legend](fontsize = 6., loc = 2, ncol = 2)
      subplots_adjust(left = 0.15, bottom = 0.16)
      show()
      xlabel("false alarm probability", labelpad = -1.0)
      ylabel("detection probability", labelpad = 0.)
      savefig("$(nu)_$(j)detect.pdf")
    end
  end
  ret, retrx
end

ν = 5
str = "tstudent_$ν-t_size-50_malfsize-10-t_100000_1000.jld2"

r = load("roc"*str)["roc"]
rr = load("rocrx"*str)["roc"]

h, rx = plotdet(r, rr, 5, ν)

function plotauc(h, rx, nu = 10)
  x = collect(1:1:size(h,1))
  mpl.rc("font", family="serif", size = 7)
  fig, ax = subplots(figsize = (2.5, 2.))
  plot(x, h, "--", label = "Alg. 1", color = "blue")
  plot(x, rx, "--", label = "RX", color = "red")
  ax[:legend](fontsize = 6., loc = 2, ncol = 2)
  subplots_adjust(left = 0.15, bottom = 0.16)
  xlabel("no. experiment", labelpad = -1.0)
  ylabel("AUC", labelpad = 0.)
  savefig("$(nu)AUC.pdf")
end

plotauc(h, rx, ν)



function main(args)
  s = ArgParseSettings("description")
  @add_arg_table s begin
    "file"
    help = "the file name"
    arg_type = String
  end
  parsed_args = parse_args(s)
  data = load(parsed_args["file"])
end

main(ARGS)
