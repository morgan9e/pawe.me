# import asyncio, aiohttp, aiofiles
import json, os, sys
import requests, time
# from tqdm import tqdm

def byteSize(size):
    pr = ""
    if size > 1024:
        size = round(size / 1024, 1)
        pr = "K"
    if size > 1024:
        size = round(size / 1024, 1)
        pr = "M"
    if size > 1024:
        size = round(size / 1024, 1)
        pr = "G"
    return f"{size}{pr}"

if len(sys.argv) != 2:
    print("Usage: getFiles.py [fetch file]")
    sys.exit()

listf = sys.argv[1]
if not os.path.exists(listf):
    print("There is no such file..")
    sys.exit()

print(f"Downloading from fetchFile {listf}")

def spchr(string, num = 25, pad = 0):
    if len(string) > num:
        string = string[0:20] + ".." + string[-4:]
    if pad > num:
        string = string + ' '*(pad-len(string))
    return string

with open(listf, 'r') as f:
    jstr = json.loads(f.read())

for stage in jstr:
    for redirs in stage.keys():
        der = redirs.split('/')
        for i in range(len(der)):
            dpath = '/'.join(der[0:i])
            if not os.path.exists(dpath) and dpath:
                print(f"[*] Making new directory {dpath}")
                os.mkdir(dpath)

for stage in jstr:
    for dosta in stage:
        print(f"[*] Downloading path {dosta}")
        fpaths = []
        furls = []

        for fls in stage[dosta]:
            fna = list(fls.keys())[0]
            fpa = fls[fna]
            fpaths.append(dosta + fna)
            furls.append(fpa)

        assert len(fpaths) == len(furls)

        # pbar = tqdm(total=len(fpaths))
        # print(furls)
        dlist = []
        for url, path in zip(furls, fpaths):
            if os.path.exists(path):
                flen = os.path.getsize(path)
                wlen = requests.get(url, stream=True).headers['Content-length']
                if int(flen) != int(wlen):
                    dlist.append((path, url))
            else:
                dlist.append((path, url))

        for path, url in dlist:
            print(f"[*] Fetch {url} ", end = "")
            wfil = requests.get(url, stream=True)
            wlen = wfil.headers['Content-length']
            print(byteSize(int(wlen)))
            
            with open(path, 'wb') as f:
                if wlen is None: # no content length header
                    f.write(wfil.content)

                else:
                #    pbar = tqdm(total=int(wlen), desc=spchr(' '+path, pad = 30))
                    for data in wfil.iter_content(chunk_size=4096):
                        f.write(data)
                       # print(".", end = "")
                     #   pbar.update(len(data))
          # print()
# async def getHTTP(session, url):
#     async with session.get(url) as resp:
#         try:
#             reqa = await resp.read()
#         # pbar.update(1)
#             return reqa
#         except:
#             print(url)
#             return

# async def agetReq():
#     async with aiohttp.ClientSession() as session:
#         tasks = []
#         for url in furls:
#             tasks.append(asyncio.ensure_future(getHTTP(session, url)))

#         getReqs = await asyncio.gather(*tasks)

#         for i, getReq in enumerate(getReqs):
#             async with aiofiles.open(fpaths[i], mode='wb') as handle:
#                 await handle.write(getReq)

# asyncio.run(agetReq())
