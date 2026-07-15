import sys
import json
from jupyter_client import KernelManager

def main ():
	km = KernelManager ()
	km.start_kernel (stdout = sys.stderr, stderr = sys.stderr)

	kc = km.client ()
	kc.start_channels ()
	kc.wait_for_ready (timeout = 5)

	for line in sys.stdin:
		# print (line)
		line = line.strip ()
		if not line:
			continue
	
		try:
			payload = json.loads (line)
			code_str = payload.get ('code', '')

			kc.execute (code_str)

			while True:
				try:
					msg = kc.get_iopub_msg (timeout = 10)
					msg_type = msg['header']['msg_type']
					content = msg['content']
			
					match msg_type:
						case 'stream':
							print (json.dumps ({
								'name': content['name'],
								'output_type': msg_type,
								'text': [f'{text}\n' for text in content['text'].split ('\n') if text != '']
							}), flush = True)

						case 'display_data':
							print (json.dumps ({
								'output_type': msg_type,
								'data': {
									'text/plain': [content['data']['text/plain']],
									'image/png': content['data']['image/png']
									},
								'metadata': content['metadata']
							}), flush = True)

						case 'error':
							print (json.dumps ({
								'ename': content['ename'],
								'evalue': content['evalue'],
								'output_type': msg_type,
								'traceback': content['traceback']
							}), flush = True)
						case 'status':
							if content['execution_state'] == 'idle':
								print (json.dumps ({
										'output_type': 'neobook_status',
										'state': 'idle'
								}), flush = True)
								break

						case _:
							# print ('some other case')
							pass

				except Exception:
					break
		except Exception as e:
			pass
	
	kc.stop_channels ()
	km.shutdown_kernel ()

if __name__ == '__main__':
	# code = sys.stdin.read ()
	# run_code (code)
	main ()
