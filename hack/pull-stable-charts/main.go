package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	urllib "net/url"
	"os"
	"path"
	"path/filepath"

	ioutil2 "github.com/appscode/go/ioutil"
	"github.com/appscode/go/log"
	logs "github.com/appscode/go/log/golog"
	"github.com/appscode/go/runtime"
	"github.com/golang/glog"
	"k8s.io/helm/pkg/repo"
)

const (
	dirPrefix = "charts"
	indexURL  = "https://kubernetes-charts.storage.googleapis.com/index.yaml"
	indexFile = "index.yaml"
)

var chartNames = []string{
	"g2",
	"kubed",
	"kubedb",
	"searchlight",
	"stash",
	"swift",
	"voyager",
}

// filePath: /tmp/swift311308022/index.yaml
// filePath: /tmp/swift311308022/test-chart-0.1.0.tgz
func download(repoURL string, filePath string, replace bool) error {
	if !replace {
		if _, err := os.Stat(filePath); err == nil {
			log.Infoln("File already exists:", filePath)
			return nil
		}
	}

	dir := path.Dir(filePath)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if err = os.MkdirAll(dir, 0777); err != nil {
			return err
		}
	}

	log.Infoln("Downloading", repoURL, "to", filePath)

	output, err := os.Create(filePath)
	if err != nil {
		log.Infoln("Error while creating", filePath, "-", err)
		return err
	}
	defer output.Close()

	u, err := urllib.Parse(repoURL)
	if err != nil {
		log.Infoln("failed to parse url. reason: %s", err)
		return err
	}

	req, err := http.NewRequest(http.MethodGet, u.String(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept-Encoding", "gzip, deflate")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Infoln("Error while downloading", u.String(), "-", err)
		return err
	}
	defer resp.Body.Close()

	n, err := io.Copy(output, resp.Body)
	if err != nil {
		log.Infoln("Error while downloading", u.String(), "-", err)
		return err
	}

	log.Infoln(n, "bytes downloaded")
	return nil
}

func downloadCharts() error {
	chartDir, err := ioutil.TempDir(os.TempDir(), dirPrefix)
	if err != nil {
		return err
	}
	defer os.RemoveAll(chartDir) // clean up tmp dir
	glog.Infoln("Chart dir:", chartDir)

	u, err := urllib.Parse(indexURL)
	if err != nil {
		return err
	}
	indexFile := filepath.Join(chartDir, u.Path)
	err = download(indexURL, indexFile, false)
	if err != nil {
		return err
	}
	index, err := repo.LoadIndexFile(indexFile)
	if err != nil {
		return err
	}

	for _, chart := range chartNames {
		for _, v := range index.Entries[chart] {
			chartURL := v.URLs[0]

			fmt.Println(chartURL)
			u, err := urllib.Parse(chartURL)
			if err != nil {
				return err
			}
			err = download(chartURL, filepath.Join(chartDir, chart, u.Path), false)
			if err != nil {
				return err
			}
		}
	}

	d := runtime.GOPath() + "/src/github.com/appscode/charts/stable"
	return ioutil2.CopyDir(d, chartDir)
}

func main() {
	logs.InitLogs()
	defer logs.FlushLogs()

	err := downloadCharts()
	if err != nil {
		glog.Fatalln(err)
	}
}
