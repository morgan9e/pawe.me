import requests, json, sys
from bs4 import BeautifulSoup as bs4

def tree(idx: int, flag = False) -> str:
	idx += 1
	if idx == 1:
		if flag :
			return "├────"	
		return "├──"
	elif idx == 2:
		if flag :
			return "│   ├────"
		return "│   ├──"
	else:
		if flag :
			return "│   " * (idx - 2) + "├────"
		return "│   " * (idx - 2) + "├──"

def parseIndex(url, base = "", idx = 0, dirs = [], ret = []):

	print(f"D {(tree(idx)+url):<40}  {''.join(dirs):>80}")
	html = bs4(requests.get(base + url).text, features="html.parser")

	hrefs = [a["href"] for a in html.find_all('a')]
	hrefs = [i for i in hrefs if i[0] != '?']
	fls = []
	for href in hrefs:
		if href[-1] == "/":  # if dir
			if href[0] != "/" and href[0] != ".":
				parseIndex(href, base + url, idx + 1, dirs + [href], ret)
		else:
			if href[0:2] == "./" and "/" not in href[2:]:
				href = href[2:]
			assert "/" not in href
			print(f"F {(tree(idx, 1)+href):<80}") # if file
			fls.append(href)
	
	while len(ret) <= idx:
		ret.append({})

	if ''.join(dirs) not in ret[idx].keys():
		ret[idx][''.join(dirs)] = []

	for fl in fls:
		ret[idx][''.join(dirs)].append({fl: base + url + fl})

	return ret


if __name__ == "__main__":

	if len(sys.argv) != 3 and len(sys.argv) != 4:
	    print("Usage: createFetch.py [URL] [Path] (fetch)")
	    sys.exit()

	# urls = {"archlinuxarm": "http://jp.mirror.archlinuxarm.org/", "asahilinux": "https://cdn.asahilinux.org/", "linux-surface": "https://pkg.surfacelinux.com/arch/"}

	if "http" in sys.argv[1]:
	    if input(f"[*] Download from {sys.argv[1]}? ") in "Yy":
	        url = sys.argv[1]
	    else:
	        sys.exit()
	else:
	    print("[*] Not supported")
	    sys.exit()

	bpath = sys.argv[2]
	assert(bpath[-1] == '/')

	print()
	print(f"[*] Downloading File list from {url} with base path {bpath}")

	files = parseIndex('', base = url, dirs = [bpath])
	filename = url.split('/')[2]+'.fetch'

	if len(sys.argv) == 4:
		filename = sys.argv[3]

	with open(filename, 'w') as f:
		f.write(json.dumps(files, indent=4))	

	print()	
	print(f"[*] Saved to {filename}.")